# pcm — Personal Credentials Manager

post_install() {
  curl -fsSL https://raw.githubusercontent.com/rjayroach/pcm/main/install.sh | bash
  target="$XDG_CONFIG_HOME/zsh/pcm.zsh"
  rm -f "$target"
  ln -s "$XDG_DATA_HOME/pcm/pcm.zsh" "$target"
}
