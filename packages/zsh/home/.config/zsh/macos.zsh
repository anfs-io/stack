# macos

[[ "$(os)" != "macos" ]] && return

ip_addr() {
  route get 8.8.8.8 | grep interface | awk '{print $2}' | xargs ifconfig \
    | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | head -1
}

alias up="caffeinate -d"
