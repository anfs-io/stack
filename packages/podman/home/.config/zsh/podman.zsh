# podman

alias docker=podman

alias pc="podman compose $@"
alias pcd="pc down $@"
alias pcu="pc \up $@"
alias pcud="pc \up - $@"

alias pps="podman ps"
alias ppsa="pps --all"
alias prm="podman rm"


# disables podman compose notification
export PODMAN_COMPOSE_WARNING_LOGS=false

# export DOCKER_HOST="unix://$HOME/.local/share/containers/podman/machine/podman.sock"

if [[ "$(podman machine inspect --format '{{.State}}' 2>/dev/null)" != "running" ]]; then
  podman machine start
fi
