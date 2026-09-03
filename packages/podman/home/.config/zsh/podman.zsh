# podman

alias docker=podman

# Docker
alias dcd="docker compose down"
alias dvls="docker volume ls"

alias pd="podman-compose down"
alias pps="podman ps"
alias ppsa="pps --all"
alias prm="podman rm"
alias pu="podman-compose up"
alias pud="pu -d"

# disables podman compose notification
export PODMAN_COMPOSE_WARNING_LOGS=false

# export DOCKER_HOST="unix://$HOME/.local/share/containers/podman/machine/podman.sock"
