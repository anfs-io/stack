# mise

if ! command -v mise >/dev/null 2>&1; then
  return
fi

# /opt/homebrew/share/zsh/site-functions

eval "$(mise activate zsh)"

alias mi="mise install"
alias mra="mise run all"
alias mtd="mise trust ."
alias mui="mise upgrade --interactive"

mconf() {
  local dir=$XDG_CONFIG_HOME/mise/conf.d file="." ext="toml"
  load_conf "$@"
}
