# python.zsh

# TODO: requires a refactor of load_conf to not assume the '.' before an extension
#       due to ext="-requirements.txt"
pconf() {
  local dir=$XDG_DATA_HOME/python file="" ext="-requirements.txt"
  load_conf "$@"
}

pstack() {
  local pydir="$XDG_DATA_HOME/python" stack="$1"

  uv venv .venv
  source .venv/bin/activate
  uv pip install -r "$pydir/${stack}-requirements.txt"

  echo '[env]\n_.python.venv = ".venv"' > .mise.toml
  mise trust
}
