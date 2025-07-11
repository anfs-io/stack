# packer repo commands

# packer cache dir
export PACKER_CONFIG_DIR="$HOME/.local/share/packer"

# packer_dir() { ~/dev/ops/packer/.builds/base/proxmox-iso }
# packer_dir() { ~/dev/ops/packer/.builds/base/debian-bookworm }
packer_dir() { "$PARA_HOME/professional/areas/home-lab/provider/packer" }

pc() {
  cd ~/packer
  ./packer.yml "$@"
  packer_dir
}

pb() {
  packer_dir
  packer build -var-file=./_build.pkrvars.hcl .
}

pcb() {
  pc
  pb
}

pt() {
  cd ~/packer
  tree .builds
}

# Testing
packer_parse() {
  ruby -e "puts 'parse the yaml playbook for the build'"
}
