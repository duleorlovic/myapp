# config valid for current version and patch releases of Capistrano
lock "~> 3.20.0"

set :application, "myapp"
set :repo_url, "git@github.com:duleorlovic/myapp.git"
set :branch, `git rev-parse --abbrev-ref HEAD`.chomp
set :deploy_to, "/home/ubuntu/#{fetch(:application)}"
# default shared/ is only config, but we need log (for server logs)
append :linked_dirs, "log", "tmp/pids", "tmp/cache", "tmp/sockets", "public/system", "vendor", "storage"
# append :linked_files, "config/master.key" # we do not use files since we
# already export RAILS_MASTER_KEY in .rbenv using terraform

set :rbenv_ruby, File.read(".ruby-version").strip

# Start of code from: https://trk.tools/rb/capistrano-tips/-/blob/main/README.md#nodejs-and-yarn
# This is needed for precompile
set :default_env, {
  "PATH" => "$HOME/.nodenv/shims:$HOME/.nodenv/bin:$PATH",
  "NODE_ENV" => "production",
}

# namespace :deploy do
#   desc "Run rake yarn install"
#   task :yarn_install do
#     on roles(:all) do
#       within release_path do
#         execute :yarn, "install"
#       end
#     end
#   end
# end
# SSHKit.config.command_map.prefix[:yarn].unshift "$HOME/.nodenv/bin/nodenv exec"
# before "deploy:assets:precompile", "deploy:yarn_install"
# End of code from: https://trk.tools/rb/capistrano-tips/-/blob/main/README.md

# Default branch is :master
# ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp

# Default deploy_to directory is /var/www/my_app_name
# set :deploy_to, "/var/www/my_app_name"

# Default value for :format is :airbrussh.
# set :format, :airbrussh

# You can configure the Airbrussh format using :format_options.
# These are the defaults.
# set :format_options, command_output: true, log_file: "log/capistrano.log", color: :auto, truncate: :auto

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
# append :linked_files, "config/database.yml", 'config/master.key'

# Default value for linked_dirs is []
# append :linked_dirs, "log", "tmp/pids", "tmp/cache", "tmp/sockets", "public/system", "vendor", "storage"

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for local_user is ENV['USER']
# set :local_user, -> { `git config user.name`.chomp }

# Default value for keep_releases is 5
# set :keep_releases, 5

# Uncomment the following to require manually verifying the host key before first deploy.
# set :ssh_options, verify_host_key: :secure

# Start of code from: https://trk.tools/rb/capistrano-tips/-/blob/main/README.md#puma
namespace :puma do
  desc "Restart puma service"
  task :restart do
    on roles(:app) do
      execute "sudo service puma restart"
    end
  end

  after "deploy:published", "puma:restart"
end
# End of code from: https://trk.tools/rb/capistrano-tips/-/blob/main/README.md
