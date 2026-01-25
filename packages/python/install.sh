# python

dependencies() {
  echo "mise"
}

post_install() {
  source <(mise activate bash)
  mise install python uv
}
