Vagrant.configure("2") do |config|
  config.vm.provider "virtualbox" do |vb, vb_config|
    # list of all machines can be found https://atlas.hashicorp.com/boxes/search
    vb_config.vm.box = "ubuntu/trusty64"
    vb.memory = "2048"
    vb_config.vm.provision :shell, inline: $script, keep_color: true
    vb_config.vm.network :private_network, ip: $server_ip
  end
end

# $ruby_version = `grep "^ruby" Gemfile | awk "{print $2}"`
$ruby_version = `ruby --version | awk "{print $2}"`.split("p").first # 2.3.1p112
$public_key = `cat ~/.ssh/id_rsa.pub`.strip
$server_ip = "192.168.3.2"

$script = <<-SCRIPT
set -e # Any commands which fail will cause the shell script to exit immediately
set -x # show command being executed
L=en_US.UTF-8
update-locale LANG=$L LANGUAGE=$L LC_ALL=$L # needed for database default enc

echo "STEP: update"
# apt-get -y update > /dev/null # update is needed to set proper apt sources
if [ "`id -u deploy`" = "" ]; then
  echo "STEP: creating user deploy (without sudo access)"
  useradd deploy -md /home/deploy --shell /bin/bash
  echo deploy:deploy | chpasswd # change password to 'deploy'
  echo STEP: generate keys and adding host public key to vb authorized keys
  sudo -i -u deploy /bin/bash -c "yes '' | ssh-keygen -N ''"
  sudo -i -u deploy /bin/bash -c "echo #{$public_key} >> ~/.ssh/authorized_keys"
  # cap staging git:check will add to known hosts
  # sudo -i -u deploy /bin/bash -c "ssh-keyscan #{$server_ip[0..-2]+"1"} >> ~/.ssh/known_hosts"

  # gpasswd -a deploy sudo # add to sudo group
  # echo "deploy ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/deploy # don't ask for password when using sudo
  # if [ ! "`id -u vagrant`" = "" ]; then
  #   usermod -a -G vagrant deploy # adding to vagrant group if vagrant exists
  # fi
else
  echo "STEP: user deploy already exists"
fi

if [ "`which git`" = "" ]; then
  echo "STEP: install development tools: git node ..."
  apt-get -y install build-essential curl git nodejs
else
  echo "STEP: development tools already installed"
fi

if [ "`which nginx`" = "" ]; then
  echo "STEP: install ngix server"
  apt-get -y install nginx
  cat >> /etc/nginx/sites-available/default << NGINX_CONFIG
  #{$nginx_config}
NGINX_CONFIG
else
  echo "STEP: nginx already installer"
fi

export DATABASE_URL=postgresql://deploy:deploy@localhost/myapp_production
DATABASE_NAME=${DATABASE_URL##*/}
if [ `echo $DATABASE_URL | cut -f 1 -d ':'` = "postgresql" ]; then
  if [ "`which psql`" = "" ]; then
    echo "STEP: installing postgres"
    apt-get -y install postgresql postgresql-contrib libpq-dev
  else
    echo STEP: postgres already installed
  fi
  if [ "`sudo -u postgres psql postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='deploy'"`" = "1" ]; then
    echo STEP: postgres user 'deploy' already exists
  else
    echo STEP: create postgresql database user deploy
    sudo -u postgres createuser --superuser --createdb deploy
    sudo -u postgres psql -U postgres -d postgres -c "alter user deploy with password 'deploy';"
  fi
  if sudo -u postgres psql -lqt | cut -d \\\| -f 1 | grep -wq $DATABASE_NAME; then
    echo STEP: $DATABASE_NAME already exists
  else
    echo STEP: creating $DATABASE_NAME
    sudo -u deploy createdb $DATABASE_NAME
  fi
else
  echo STEP: create mysql2 database user deploy
  if [[ `echo "SELECT user FROM mysql.user WHERE user = 'deploy'" | mysql` = "" ]]; then
    echo CREATE USER 'deploy'@'localhost' | mysql --user=root
    echo GRANT ALL PRIVILEGES ON * . * TO 'deploy'@'localhost' | mysql --user=root
    #FLUSH PRIVILEGES;
  else
    echo STEP: mysql user 'deploy' already exists
  fi
fi

if [ "`sudo -i -u deploy which bundle`" = "" ]; then
#if [ ! -f /usr/local/rvm/scripts/rvm ]; then
  echo "STEP: installing rvm for system so it can download sudo requirements"
  gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
  # multi-user install to /usr/local/rvm, we use vagrant since it is in sudoers list
  sudo -i -u vagrant /bin/bash -c "curl -sSL https://get.rvm.io | sudo -i bash -s stable --ruby"
  usermod -a -G rvm deploy # adding to rvm group so it can access /usr/local/rvm
  usermod -a -G rvm vagrant # adding to rvm group so it can access /usr/local/rvm

  if [ ! "#{$ruby_version}" = "" ]; then
    echo "STEP: installing ruby version #{$ruby_version}"
    # sometime we need to remove old cache
    # rm -rf $rvm_path/archives/rubygems-* $rvm_path/user/{md5,sha512}
    sudo -i -u vagrant /bin/bash -c "rvm install #{$ruby_version}"
  fi

  echo "STEP: install bundle for deploy"
  sudo -i -u deploy /bin/bash -c "rvm install 2.4"
  sudo -i -u deploy /bin/bash -c "gem install bundler"
else
  echo "STEP: rvm and bundler already installed"
fi
SCRIPT

$nginx_config = <<-NGINX_CONFIG
# https://www.digitalocean.com/community/tutorials/deploying-a-rails-app-on-ubuntu-14-04-with-capistrano-nginx-and-puma
upstream app {
    # Path to Unicorn SOCK file, as defined previously
    server unix:/home/deploy/myapp/shared/sockets/puma.sock;
}

server {
    listen 80 default_server deferred;
    # server_name example.com;
    root /home/deploy/myapp/current/public;
    access_log /home/deploy/myapp/current/log/nginx.access.log;
    error_log /home/deploy/myapp/current/log/nginx.error.log info;


    location ^~ /assets/ {
      gzip_static on;
      expires max;
      add_header Cache-Control public;
    }

    try_files $uri/index.html $uri @app;
    location @app {
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Host $http_host;
        proxy_redirect off;
    }

    error_page 500 502 503 504 /500.html;
    client_max_body_size 10M;
    keepalive_timeout 10;
}
NGINX_CONFIG
