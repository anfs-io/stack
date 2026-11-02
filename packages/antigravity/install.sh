# antigravity

# The skills CLI detects the IDE by ~/.gemini/antigravity, which the app only creates on first
# launch; without it, skills installed for it (wsm, psm) read as partial until then
post_install() {
  mkdir -p "$HOME/.gemini/antigravity"
}
