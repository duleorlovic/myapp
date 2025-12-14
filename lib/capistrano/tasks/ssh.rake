# Start of code from: https://trk.tools/rb/capistrano-tips/-/blob/main/lib/capistrano/tasks/ssh.rake
#
# Install with:
#   wget -P lib/capistrano/tasks https://trk.tools/rb/capistrano-tips/-/raw/main/lib/capistrano/tasks/ssh.rake
# bundle exec cap production ssh
#
desc "SSH to app instance"
task "ssh" do
  on roles(:app) do |host|
    command = "cd #{fetch(:deploy_to)} && if [ -d current ]; then cd current; fi && exec $SHELL -l"
    puts command if fetch(:log_level) == :debug
    if host.ssh_options[:keys].nil?
      exec "ssh -l #{host.user} #{host.hostname} -p #{host.port || 22} -t '#{command}'"
    else
      exec "ssh -i #{host.ssh_options[:keys]} -l #{host.user} #{host.hostname} -p #{host.port || 22} -t '#{command}'"
    end
  end
end

desc "SSH to worker instance"
task "ssh-worker" do
  on roles(:worker) do |host|
    command = "cd #{fetch(:deploy_to)} && if [ -d current ]; then cd current; fi && exec $SHELL -l"
    puts command if fetch(:log_level) == :debug
    if host.ssh_options[:keys].nil?
      exec "ssh -l #{host.user} #{host.hostname} -p #{host.port || 22} -t '#{command}'"
    else
      exec "ssh -i #{host.ssh_options[:keys]} -l #{host.user} #{host.hostname} -p #{host.port || 22} -t '#{command}'"
    end
  end
end
# End of code from: https://trk.tools/rb/capistrano-tips/-/blob/main/lib/capistrano/tasks/ssh.rake
