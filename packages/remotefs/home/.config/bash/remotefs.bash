# remotefs.bash — the portable part is .config/sh/remotefs.sh

# Only function definitions and a `complete`, so re-sourcing on _ppm_shell_reload is harmless
command -v remotefs >/dev/null 2>&1 && eval "$(command remotefs completion bash)"
