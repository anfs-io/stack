# Packer

# packer_dir() { ~/dev/ops/packer/.builds/base/proxmox-iso }
# packer_dir() { ~/dev/ops/packer/.builds/base/debian-bookworm }

# PROJECTS_DIR is deprecated
# export PACKER_DIR="$PROJECTS_DIR/pcs/packer"
export PACKER_DIR="$XDG_DATA_HOME/pcs/packer"

# export PACKER_CONFIG_HOME="$XDG_CONFIG_HOME/packer"
export PACKER_CACHE_DIR="$XDG_CACHE_HOME/packer"

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
