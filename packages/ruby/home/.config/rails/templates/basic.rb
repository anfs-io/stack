# templates/basic.rb

generate(:scaffold, "person name:string")
route "root to: 'people#index'"
rails_command("db:migrate")
