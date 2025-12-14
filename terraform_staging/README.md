# Terraform capistrano provision on AWS

This terraform project enable you to deploy using capistrano.
To deploy on https://staging.myapp.com/ , you should be able to ssh to both
worker and app
```
ssh ubuntu@staging-worker.myapp.com
# ssh through loadbalancer is usually not allowed
# ssh ubuntu@staging.myapp.com
```
If you do not have access, ask some of the previous developers to add your
public key to authorized_keys those servers servers.

You need aws elbas keys
```
set -a && source terraform.tfvars && set +a
export AWS_ACCESS_KEY_ID=$terraform_aws_access_key AWS_SECRET_ACCESS_KEY=$terraform_aws_secret_key AWS_REGION=$terraform_aws_region
```
Deploy current branch
```
bundle exec cap staging deploy
```

## First time provision

Start example project
```
rails new myapp -d postgresql
cd myapp
git add . && git commit -am"rails new myapp -d postgresql"
rails g scaffold posts title body:text
rails db:migrate
sed -i "" -e "/^end$/i \\
  root 'posts#index'\
" config/routes.rb
git add . && git commit -am"Add posts"
```
Clone this repo to your project:
```
git clone http://trk.tools/tf/terraform-capistrano-on-aws.git
rm -rf terraform-capistrano-on-aws/.git
```

You can rename for specific env
```
mv terraform-capistrano-on-aws terraform_staging
```

It also uses several files
```
# from root of the project
mkdir -p config/etc/systemd
mv terraform-staging-capistrano/etc/systemd/puma.server config/etc/systemd

mkdir -p config/etc/nginx/sites-enabled
mv terraform-staging-capistrano/etc/nginx/sites-enabled/puma.server config/etc/nginx/sites-enabled
```

Also change default puma config to use socker
```
# config/puma.rb
# Start of code from: https://trk.tools/tf/terraform-capistrano-on-aws/-/blob/main/README.md#first-time-provision
# Set up socket location used in config/etc/nginx/sites-enabled/nginx_puma
bind "unix://#{File.expand_path("..", __dir__)}/tmp/sockets/puma.sock"
# End of code from: https://trk.tools/tf/terraform-capistrano-on-aws/-/blob/main/README.md#first-time-provision
```

Commit initial terraform scripts

```
git add . && git commit -am"Add terraform, puma and nginx"
```

We need `terraform-administrator-access` iam user with AdministratorAccess and
paste keys to tfvars file (`cp terraform.tfvars_example terraform.tfvars`)
```
# terraform_staging/terraform.tfvars
# aws root login staging@myapp.com Mypass...
# https://us-east-1.console.aws.amazon.com/iam/home?region=ap-southeast-1#/users/details/terraform-administrator-access?section=permissions
terraform_aws_access_key="AK..."
terraform_aws_secret_key="0Pb..."
```
You can use the same as terraform_aws_secret_key keys but we need to export:
```
set -a && source terraform.tfvars && set +a
export AWS_ACCESS_KEY_ID=$terraform_aws_access_key AWS_SECRET_ACCESS_KEY=$terraform_aws_secret_key AWS_REGION=$terraform_aws_region
```

For the first time you also need to create ssh keys
```
cd terraform-staging-capistrano
ssh-keygen -f myapp_key
(Enter)
```
and also we need to create a bucket to store a terraform state. Note that you
need to use uniq name and also update in `providers.tf` file
```
aws s3api create-bucket --bucket myapp-capistrano-terraform-state --region us-east-1
# optional
aws s3api put-bucket-versioning --bucket myapp --region us-east-1 --versioning-configuration Status=Enabled
```
Now you can run `terraform init`.

## When server already exists

If server exists you can download keys myapp and myapp.pub and terraform.tfvars file
```
scp ubuntu@staging-worker.myapp.com:keys/myapp terraform-staging-capistrano/
scp ubuntu@staging-worker.myapp.com:keys/myapp.pub terraform-staging-capistrano/
scp ubuntu@staging-worker.myapp.com:keys/terraform.tfvars terraform-staging-capistrano/
```
Note that if you update vars you should copy back
```
scp terraform-staging-capistrano/terraform.tfvars ubuntu@staging-worker.myapp.com:keys/
```

We are using s3 to store state so we need to export AWS keys that has access
to the bucket (we can not use provider "aws" keys since backend is initialized
before providers) and also you need to create bucket before starting terraform
You can use the same as terraform_aws_secret_key keys but we need to export:
```
set -a && source terraform.tfvars && set +a
export AWS_ACCESS_KEY_ID=$terraform_aws_access_key AWS_SECRET_ACCESS_KEY=$terraform_aws_secret_key AWS_REGION=$terraform_aws_region
```

## Terraform plan

Customize `variables.tf` to match your needs, like ruby and node version.
You should use uniq name for s3 bucket instead of `myapp-uniq-bucket-name`

## First time deploy

Install `capistrano` https://github.com/capistrano/capistrano gem and
`capistrano-rails` and `elbas` gem
(note that we are using terraform to install puma and rbenv so no need for
`capistrano-puma` or `capistrano-rbenv` gems, but 
```
# Gemfile
group :development do
  gem "capistrano", "~> 3.17", require: false
  gem "capistrano-rbenv", "~> 2.2" # to set correct paths for ruby commands
  gem "capistrano-rails", "~> 1.6", require: false # to run bundle install
  # Use fork until PR is merged https://github.com/lserman/capistrano-elbas/pull/47
  gem "elbas", github: "duleorlovic/capistrano-elbas"
end
```
and
```
# Capfile
require "capistrano/rbenv"
require "capistrano/rails"
require "elbas/capistrano"
```
and run
```
bundle install

# generate config/deploy.rb
bundle exec cap install
```

Edit capistrano main configuration based on
https://trk.tools/rb/capistrano-tips#main-configuration

```
# config/deploy.rb
....
```
and ssh.rake https://trk.tools/rb/capistrano-tips/-/blob/main/lib/capistrano/tasks/ssh.rake

Server can use ip addresses or put a domain name records on your DNS registrar
(for example cloudflare can leave Proxy status proxied through CF).
Note that `myapp-autoscaling-group` should match you auto scaling group name and
that `18.206.65.85` should match `terraform output ssh_commands_worker`
```
# config/deploy/staging.rb
autoscale "myapp-autoscaling-group" do |_server, i|
  roles = if i.zero?
    %w[app web first]
  else
    %w[app web]
  end
  {
    user: "ubuntu",
    roles: roles,
    ssh_options: {
      keepalive: true, # https://github.com/capistrano/capistrano/issues/2066#issuecomment-1374911694
    }
  }
end
server "18.206.65.85",
  user: "ubuntu",
  roles: %w[db worker],
  ssh_options: {
    keepalive: true, # https://github.com/capistrano/capistrano/issues/2066#issuecomment-1374911694
  }
```

Since deploy to web requires assets precompile and it also uses rails
initializations and check for database columns, we need to deploy to worker role
(it will automatically run db migrate task and create a table if does not exists)
```
be cap staging deploy ROLES=worker
# create table
# create table
```
than we can deploy web role
```
be cap staging deploy ROLES=web
# assets precompile
```
and we can seed test data
```
be cap staging db:seed
```

and now you should be able to navigate to
http://staging-capistrano.myapp.com


## Debug sidekiq service

Sidekiq service should start successfully after any subsequent deploy.
You can check the status with:
```
systemctl --user daemon-reload # if you update service file
systemctl --user enable sidekiq.service
systemctl --user stop sidekiq.service
systemctl --user start sidekiq.service
systemctl --user status sidekiq.service
```
or from local machine
```
be cap staging sidekiq:start
```

Logs
```
# see sidekiq.log
tail -f /var/log/syslog
```

### Debug puma service

Main config is in `config/etc/systemd/system/puma.service`

After changing env variables you should redeploy or restart services
```
sudo systemctl restart puma.service
```
check status
```
sudo systemctl status puma.service

# or similar
sudo service puma status
```

Logs
```
tail -f /var/log/nginx/*
tail -f myapp/current/log/*

multitail -f /var/log/nginx/access.log /var/log/nginx/error.log /home/ubuntu/myapp/current/log/*
```

### Healts check type

On initial deploy we used `health_check_type = "EC2"` so autoscaling does not
interfere with deployment (EC2 check is only based on instance accessibility,
not instance CPU).
TODO: we can use capistrano to set `health_check_type = "EC2"` on each deploy
We need manually set to `health_check_type = "ELB"` so AWS can scale based on
CPU.
```
# terraform_staging/resources.tf
  health_check_type      = "ELB" # TODO: after first deploy change from EC2 to ELB
```

### RBENV ENV variables

When you need to update ENV variable to match `config/secrets.yml`, do it inside
terraform template `terraform_staging/templates/rbenv.vars.tpl`

```
vi terraform_staging/resources.tf
vi terraform_staging/templates/rbenv.vars.tpl

cd terraform_staging
terraform apply -auto-approve
cd -
```
Pull cloudinit userdata on worker

```
be cap staging ssh-worker
sudo su
call
exit
less ~/myapp/.rbenv-vars
```

For the app server, terraform will trigger asg_instance_refresh so you can check
if "Instance Refresh" is generated and when it completes (if not, you can click
on "Start Instance Refresh" to rotate autoscaling group instance
https://us-east-1.console.aws.amazon.com/ec2/home?region=us-east-1#AutoScalingGroupDetails:id=myapp;view=instanceRefresh
New instance will automatically run fresh
cloudinit so you just need to check if instance id is new and rbenv are there
Default cooldown time is 300 seconds and during that time Autoscaling will not
perform other activities.

```
be cap staging ssh
curl -sL instance-id.trk.tools
c status
less ~/myapp/.rbenv

git commit -am"Update secrets"
git push -f
be cap staging deploy
```

## Errors

TODO: on first deploy I see
```

bundler: failed to load command: cap
(/Users/dule/.asdf/installs/ruby/3.1.6/bin/cap)
/Users/dule/.asdf/installs/ruby/3.1.6/lib/ruby/gems/3.1.0/gems/airbrussh-1.6.0/lib/airbrussh/capistrano/tasks.rb:90:in `initialize': No such file or directory @ rb_sysopen - log/capistrano.log (Errno::ENOENT)
```
and that is because of low memory.
