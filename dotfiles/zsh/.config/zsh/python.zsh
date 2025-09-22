# python.zsh

alias pyenv='echo $VIRTUAL_ENV'

pydir() { $HOME/.local/share/python }

pymkenv() {
  (pydir; python3 -m venv $1)
}

# pyrmenv() {
#   (deactivate; pydir; rm -rf $1)
# }

# TODO: concatenate pydir and source on one line
pyactivate() {
  # pydir
  # source $1/bin/activate
}

# pyactivate lstack
# source $HOME/.local/share/python/lstack/bin/activate
