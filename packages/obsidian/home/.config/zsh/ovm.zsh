# ovm.zsh — ovm's zsh integration: its completion.
# zcomp comes from stack/zsh's aliases.zsh, which the same rc sources first.

command -v ovm >/dev/null 2>&1 || return 0

(( $+functions[zcomp] )) && zcomp ovm
