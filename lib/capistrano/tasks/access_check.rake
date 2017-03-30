desc "Check we can write"
task :check_we_can_write do
  on roles(:all) do |host|
    if test "[ -w #{fetch(:deploy_to)} ]"
      info "#{fetch(:deploy_to)} is writable on #{host}"
    else
      error "#{fetch(:deploy_to)} is not writable on #{host}"
    end
  end
end

desc "uptime"
task :uptime do
  on roles(:all) do |host|
    info "uptime for #{host} is #{host.roles.to_a.join(', ')} \t #{capture(:uptime)}"
  end
end
