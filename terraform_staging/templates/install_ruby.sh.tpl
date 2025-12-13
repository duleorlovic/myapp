# input variables:
#   elasticache-cluster-redis-address
#   ruby_version
#   bundler_version
#   node_version

# stop runcmd script on errors
- set -e
- set -x
- timedatectl set-timezone Asia/Kolkata
- echo "start default_runcmd `date` `ls /home`" >> /root/cloud_init_script.log
- apt-get update

# redis_cli test
- apt-get -y install redis-tools
- redis-cli -h ${elasticache-cluster-redis-address} ping
- echo redis-cli -h ${elasticache-cluster-redis-address} ping >> /root/cloud_init_script.log

# install dependencies
- apt-get install -y build-essential
# install ruby using rubyenv
# https://github.com/rbenv/rbenv?tab=readme-ov-file#basic-git-checkout
- apt-get install -y git curl gcc make libssl-dev libreadline-dev zlib1g-dev
- if [ ! -d /home/ubuntu/.rbenv ]; then
    sudo -u ubuntu git clone https://github.com/rbenv/rbenv.git /home/ubuntu/.rbenv;
    sudo -u ubuntu git clone https://github.com/rbenv/ruby-build.git /home/ubuntu/.rbenv/plugins/ruby-build;
    sudo -u ubuntu git clone https://github.com/rbenv/rbenv-vars.git /home/ubuntu/.rbenv/plugins/rbenv-vars;
    echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> /home/ubuntu/.bashrc;
    echo 'eval "$(rbenv init -)"' >> /home/ubuntu/.bashrc;
  fi
- sudo -u ubuntu /bin/bash -c 'export PATH="$HOME/.rbenv/bin:$PATH" && eval "$(rbenv init -)" && rbenv install --skip-existing ${ruby_version} && rbenv global ${ruby_version}'
- sudo -u ubuntu /bin/bash -c 'export PATH="$HOME/.rbenv/bin:$PATH" && eval "$(rbenv init -)" && ruby --version' >> /root/cloud_init_script.log
- sudo -u ubuntu /bin/bash -c 'export PATH="$HOME/.rbenv/bin:$PATH" && eval "$(rbenv init -)" && gem install bundler:${bundler_version}' >> /root/cloud_init_script.log
- sudo -u ubuntu /bin/bash -c 'export PATH="$HOME/.rbenv/bin:$PATH" && eval "$(rbenv init -)" && bundler --version' >> /root/cloud_init_script.log
- sudo -u ubuntu mkdir -p /home/ubuntu/myapp
- cp /root/prepare_files_for_ubuntu_user/.rbenv-vars /home/ubuntu/myapp/.rbenv-vars
- chown ubuntu:ubuntu /home/ubuntu/myapp/.rbenv-vars
- cp /root/.bash_aliases /home/ubuntu/
- chown ubuntu:ubuntu /home/ubuntu/.bash_aliases

# Install node and yarn using nodenv
# https://github.com/nodenv/nodenv?tab=readme-ov-file#basic-github-checkout
# Comments with # is not allowed in this single line command
- apt-get install -y git build-essential curl libssl-dev zlib1g-dev
- if [ ! -d /home/ubuntu/.nodenv ]; then
    sudo -u ubuntu git clone https://github.com/nodenv/nodenv.git /home/ubuntu/.nodenv;
    sudo -u ubuntu git clone https://github.com/nodenv/node-build.git /home/ubuntu/.nodenv/plugins/node-build;
    echo 'export PATH="$HOME/.nodenv/bin:$PATH"' >> /home/ubuntu/.bashrc;
    echo 'eval "$(nodenv init -)"' >> /home/ubuntu/.bashrc;
    sudo -u ubuntu /bin/bash -c 'export PATH="$HOME/.nodenv/bin:$PATH" && eval "$(nodenv init -)" && nodenv install --skip-existing ${node_version} && nodenv global ${node_version}';
    sudo -u ubuntu /bin/bash -c 'export PATH="$HOME/.nodenv/bin:$PATH" && eval "$(nodenv init -)" && node --version >> /home/ubuntu/cloud-init-finished.log';
    sudo -u ubuntu /bin/bash -c 'export PATH="$HOME/.nodenv/bin:$PATH" && eval "$(nodenv init -)" && nodenv exec npm install -g yarn';
    sudo -u ubuntu /bin/bash -c 'export PATH="$HOME/.nodenv/bin:$PATH" && eval "$(nodenv init -)" && yarn -v >> /home/ubuntu/cloud-init-finished.log';
  fi
