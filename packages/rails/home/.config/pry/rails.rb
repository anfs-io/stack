# pry/rails.rb

return unless defined?(Rails)

def r = reload!

PryRailsCommands = Pry::CommandSet.new do
  command 'cdr', 'Switch Pry context into the Rails object' do
    # pry_instance holds the current session context where you run commands
    pry_instance.run_command('cd Rails')
  end
end

Pry.config.commands.import PryRailsCommands

def project_reset_tasks
  @project_reset_tasks ||= []
end

def before_project_reset(&block)
  @before_project_reset_hooks ||= []
  @before_project_reset_hooks << block if block_given?
end

def deep_reenable(task_or_name, scope = nil)
  task = task_or_name.is_a?(Rake::Task) ? task_or_name : Rake.application.lookup(task_or_name, scope)
  return unless task

  task.reenable
  task.prerequisites.each { |prereq_name| deep_reenable(prereq_name, task.scope) }
end

def reset_project!
  if defined?(@before_project_reset_hooks) && @before_project_reset_hooks.any?
    @before_project_reset_hooks.each(&:call)
  end

  if !defined?(Rake) || Rake.application.tasks.empty?
    require 'rake'
    Rails.application.load_tasks
  end

  ActiveRecord::Base.connection_handler.clear_active_connections!
  ActiveRecord::Base.connection.disconnect! rescue nil

  base_tasks = %w[db:reset db:seed]
  all_tasks  = base_tasks + project_reset_tasks

  all_tasks.each do |task_name|
    deep_reenable(task_name)
    Rake::Task[task_name].invoke
  end

  ActiveRecord::Base.establish_connection
end
