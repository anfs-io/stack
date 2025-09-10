# rails.zsh

alias rfs="foreman start -f Procfile.dev"
alias rg="rails generate"
alias rgm="rails generate model"
alias rgs="rails generate scaffold"
alias rsb="rails server -b 0.0.0.0"

alias rua="rubocop -A ."
alias rce="rails credentials:edit"
alias rcs="rails credentials:show"

if alias rn >/dev/null 2>&1; then 
  unalias rn
fi

rn() {
  rails new --rc=$HOME/.config/rails/rc -T $*
  if [ $? -eq 0 ]; then
    # TODO: curl/wget a tmuxinator file for a rails project to this dir
    # then create a mise.toml with
    # [tasks.tmux]
    # run ln -s in the $HOME/.config/tmuxinator
  else
    # local result='not ok'
  fi
}
