# pcm — Personal Credentials Manager

install_macos() {
  install_dep dmno-dev/tap/varlock
}

post_install() {
  local repo_dir="$XDG_DATA_HOME/pcm"
  if [[ -d $repo_dir ]]; then
    if git -C "$repo_dir" rev-parse --git-dir &>/dev/null && [[ -z $(git -C "$repo_dir" status --porcelain) ]]; then
      git -C "$repo_dir" pull --ff-only
    fi
  else
    curl -fsSL https://raw.githubusercontent.com/rjayroach/pcm/main/install.sh | bash
    local target="$XDG_CONFIG_HOME/zsh/pcm.zsh"
    rm -f "$target"
    ln -s "$XDG_DATA_HOME/pcm/pcm.zsh" "$target"
  fi
  install_completion "pcm completion zsh"
}
