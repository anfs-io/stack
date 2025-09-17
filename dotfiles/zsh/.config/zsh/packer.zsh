# Packer

# packer_dir() { ~/dev/ops/packer/.builds/base/proxmox-iso }
# packer_dir() { ~/dev/ops/packer/.builds/base/debian-bookworm }
export PACKER_DIR="$PROJECTS_DIR/pcs/packer"

# export PACKER_CONFIG_DIR="$HOME/.local/share/packer"
export PACKER_CACHE_DIR="$HOME/.cache/packer"

pc() { (cd $PACKER_DIR; ./packer.yml "$@") }

pb() {
  cd $PACKER_DIR
  packer build -var-file=./_build.pkrvars.hcl .
}

pcb() {
  pc
  pb
}

pt() {
  cd $PACKER_DIR
  tree .builds
}

# Testing
packer_parse() {
  ruby -e "puts 'parse the yaml playbook for the build'"
}
