# ansible

dependencies() {
  echo "python"
}

post_install() {
  source <(mise activate bash)
  # mise use -g uv@latest
  mise install pipx:ansible
  mise_fix_ansible
}

# This is to fix a bug in mise when using uv installer
mise_fix_ansible() {
  local bin_path=$(mise bin-paths | grep ansible)
  local ansible_bin="${bin_path}/../ansible/bin"

  for cmd in ansible ansible-config ansible-console ansible-doc ansible-galaxy ansible-inventory ansible-playbook ansible-pull ansible-test ansible-vault; do
    ln -sf "${ansible_bin}/${cmd}" "${bin_path}/${cmd}"
  done

  echo "Symlinks created in ${bin_path}"
}
