# pim - Product Image Manager

dependencies() {
  echo "ruby"
}

# NOTE: these packages were here from when we were going to unpack an ISO; probably not needed
# TODO: Remove these after testing pim on a linux bare metal host
# install_linux() {
#   install_dep xz-utils fdisk parted dosfstools expect exfat-fuse
# }

install_macos() {
  install_dep qemu socat
}
