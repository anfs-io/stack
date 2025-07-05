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
    # local result='ok'
    cp -a $HOME/config/packages/gift $HOME/config/packages/$1
    mv $HOME/config/packages/$1/dotfiles/.config/tmuxinator/gift.yml $HOME/config/packages/$1/dotfiles/.config/tmuxinator/$1.yml 
    stow -t $HOME -d $HOME/config/packages/$1 dotfiles
  else
    # local result='not ok'
  fi
}
