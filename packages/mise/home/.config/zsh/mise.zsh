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
  local config_dir=$CONFIG_DIR/mise/conf.d
  local file="dev.toml"

  if [[ $1 == "ls" ]]; then
    ls $config_dir
    return
  fi

  if (( $# == 1 )); then
    file="${1}.toml"
  fi
  (cd $config_dir; nvim ${file})
}
