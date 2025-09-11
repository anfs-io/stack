# ~/.tmuxinator/helpers.rb
require 'ostruct'

class TmuxinatorConfig < OpenStruct
  def initialize(filename:, project_root: nil, profile: nil, section: nil, **options)
    @profile = profile
    @section = section
    @filename = filename
    @custom_project_root = project_root
    super(options)
  end
  
  # Path helpers
  def para_root = ENV['PARA_HOME'] || "#{ENV['HOME']}/para"
  
  def subdir(*paths) = File.join(project_root, *paths)
  
  # Auto-configuration helpers
  def project_name = File.basename(@filename, '.yml')
  
  def project_root
    return @custom_project_root if @custom_project_root

    # Convert filename to path: rws-infra-ansible.yml -> rws/infra/ansible
    project_path = project_name.gsub('-', '/')
    File.join(para_root, @profile, @section, project_path)
  end
  
  # Command helpers
  def rails_cmd(cmd) = "bundle exec rails #{cmd}"
  def k8s_cmd(cmd) = "kubectl #{cmd}"
  def tf_cmd(cmd) = "terraform #{cmd}"
  def git_cmd(cmd) = "git #{cmd}"
  def npm_cmd(cmd) = "npm run #{cmd}"
  def yarn_cmd(cmd) = "yarn #{cmd}"
  def cargo_cmd(cmd) = "cargo #{cmd}"
  def go_cmd(cmd) = "go #{cmd}"
  def bundle_cmd(cmd) = "bundle exec #{cmd}"
  
  def docker_cmd(service = nil)
    service ? "docker-compose exec #{service} bash" : "docker-compose up"
  end
  
  def ansible_cmd(playbook = nil, extra_args = "")
    return "ansible-playbook" unless playbook
    "ansible-playbook #{playbook}.yml #{extra_args}"
  end
  
  def make_cmd(target = nil)
    target ? "make #{target}" : "make"
  end
  
  def env_cmd(cmd, env = nil)
    env ? "#{env.upcase}_ENV=#{env} #{cmd}" : cmd
  end
  
  # Layout helper
  def layout(name = :main_vertical)
    layouts = {
      even_horizontal: 'even-horizontal',
      even_vertical: 'even-vertical', 
      main_horizontal: 'main-horizontal',
      main_vertical: 'main-vertical',
      main_horizontal_mirrored: 'main-horizontal-mirrored',
      main_vertical_mirrored: 'main-vertical-mirrored',
      tiled: 'tiled',
      # Use tmux list-windows to get the layout of current windows
      claude: 'f125,225x85,0,0{112x85,0,0[112x42,0,0,0,112x42,0,43,8],112x85,113,0,7}'
    }[name] || layouts[:main_vertical]     # fallback to default
  end
  
  # Common pane configurations
  def editor_panes(editor = "vim")
    [
      "#{editor} .",
      "# shell for quick commands"
    ]
  end
  
  def rails_server_panes
    [
      rails_cmd("server"),
      rails_cmd("console")
    ]
  end
  
  def k8s_monitoring_panes
    [
      k8s_cmd("get pods -w"),
      k8s_cmd("get services"),
      k8s_cmd("logs -f deployment/app")
    ]
  end
  
  def docker_dev_panes
    [
      docker_cmd,
      "docker-compose logs -f",
      "docker ps"
    ]
  end
  
  def log_panes(logs = %w[development.log test.log])
    logs.map { "tail -f log/#{_1}" }
  end
  
  def test_panes(framework = :rails)
    case framework
    when :rails then [rails_cmd("test"), "# test watcher"]
    when :node then [npm_cmd("test"), npm_cmd("test:watch")]
    when :rust then [cargo_cmd("test"), cargo_cmd("test -- --nocapture")]
    else ["# tests", "# test watcher"]
    end
  end
  
  # Project type detectors
  def rails_project?(root = nil)
    root ||= project_root
    File.exist?(File.join(root, 'Gemfile')) && 
    File.exist?(File.join(root, 'config', 'application.rb'))
  end
  
  def node_project?(root = nil)
    root ||= project_root
    File.exist?(File.join(root, 'package.json'))
  end
  
  def terraform_project?(root = nil)
    root ||= project_root
    Dir.glob(File.join(root, '*.tf')).any?
  end
  
  def ansible_project?(root = nil)
    root ||= project_root
    File.exist?(File.join(root, 'ansible.cfg')) ||
    File.exist?(File.join(root, 'playbooks')) ||
    File.exist?(File.join(root, 'roles'))
  end
  
  # Dynamic window generation
  def create_service_windows(services)
    services.map do |service|
      {
        service => {
          'root' => subdir(service),
          'layout' => dev_layout,
          'panes' => editor_panes
        }
      }
    end
  end
end
