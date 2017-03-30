namespace :my_tasks do
  desc "My first task"
  task :my_first_task do
    on roles(:all) do
      puts "Start my first task"
    end
    invoke 'my_tasks:notify'
  end

  task :notify do
    on roles(:all) do |host|
      puts "notify #{host}"
    end
  end
end
