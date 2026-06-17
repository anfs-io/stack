# seed.rb
#
# Generate a scaffold for a Person

generate(:scaffold, "person name:string")
route "root to: 'people#index'"
rails_command("db:migrate")
