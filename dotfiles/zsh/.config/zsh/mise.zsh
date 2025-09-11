# mise

if ! command -v mise >/dev/null 2>&1; then
  return
fi

eval "$(mise activate zsh)"

alias mra="mise run all"
alias mtd="mise trust ."

mconf() {
  local config_dir=$HOME/.config/mise/conf.d
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
