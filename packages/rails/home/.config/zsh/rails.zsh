# rails.zsh

alias rat="rails app:template LOCATION=$XDG_CONFIG_HOME/rails/templates.rb"

alias rce="rails credentials:edit"
alias rcs="rails credentials:show"

alias rfs="foreman start -f Procfile.dev"

alias rg="rails generate"
alias rgm="rails generate model"
alias rgs="rails generate scaffold"

alias rsb="rails server -b 0.0.0.0"

# rat() { rails app:template LOCATION=$HOME/.config/rails/templates.rb }

# if alias rn >/dev/null 2>&1; then
#   unalias rn
# fi
