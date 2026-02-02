# ghostty

# Change terminal background color (OSC 11)
function set_bg() {
  printf '\e]11;%s\e\\' "$1"
}

# Change terminal foreground color (OSC 10)  
function set_fg() {
  printf '\e]10;%s\e\\' "$1"
}

# Reset colors to default (OSC 110/111)
function reset_colors() {
  printf '\e]110\e\\'  # Reset foreground
  printf '\e]111\e\\'  # Reset background
}

# Set tab/window title (OSC 2)
function tab_title() {
  printf '\e]2;%s\e\\' "$1"
}

function sshg() {
  local host="${@: -1}"  # Get last argument (the host)
  
  case "$host" in
    *raspberry*|*pi*|*rpi*)
      set_bg '#3d0000'      # Dark red background
      tab_title "🍓 Pi: $host"
      ;;
    *prod*|*production*)
      set_bg '#4d0000'      # Brighter red for production
      tab_title "⚠️ PROD: $host"
      ;;
    *staging*)
      set_bg '#3d2600'      # Dark orange
      tab_title "🔶 Stage: $host"
      ;;
    *)
      set_bg '#001a33'      # Dark blue for other servers
      tab_title "🖥 $host"
      ;;
  esac
  
  # Run actual ssh
  command ssh "$@"
  
  # Reset when connection closes
  reset_colors
  tab_title "${PWD##*/}"
}
