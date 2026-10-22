# ovm.sh — ovm's portable shell integration.
# Sourced by both the bash and the zsh rc; the completion lives in .config/zsh/ovm.zsh.

command -v ovm >/dev/null 2>&1 || return 0

# Wrapper to handle `ovm cd` through _anfs_cd (core's anfs.sh), to what `ovm path --dir` prints:
# a vault's directory, or a document's (by id). No argument: the vault you are in; outside one it
# fails, like wsm cd outside a space, and you stay where you are.
ovm() {
  if [ "${1:-}" = "cd" ]; then
    shift
    _anfs_cd ovm "" --dir "$@"
  else
    command ovm "$@"
  fi
}
