# pdt/pcs

install_linux() {
  install_dep dnsmasq bridge-utils iproute2 nmap iperf3 \
    qemu-system-arm qemu-system-x86 qemu-system-data
}

post_install() {
  install_completion "pcs completions zsh"
}
