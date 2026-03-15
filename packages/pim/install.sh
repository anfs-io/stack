# pdt/pim - Product Image Manager

# NOTE: these packages were here from when we were going to unpack an ISO; probably not needed
# TODO: Remove these after testing pim on a linux bare metal host
#   install_dep xz-utils fdisk parted dosfstools expect exfat-fuse
install_linux() {
  install_dep qemu-system
}

install_macos() {
  install_dep qemu socat libarchive
}
