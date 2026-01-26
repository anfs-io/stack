# rails.zsh

alias rfs="foreman start -f Procfile.dev"
alias rg="rails generate"
alias rgm="rails generate model"
alias rgs="rails generate scaffold"
alias rsb="rails server -b 0.0.0.0"

alias rce="rails credentials:edit"
alias rcs="rails credentials:show"

rat() { rails app:template LOCATION=$HOME/.config/rails/templates/${1:-basic}.rb }

# if alias rn >/dev/null 2>&1; then
#   unalias rn
# fi
