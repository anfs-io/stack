# go.sh — portable (bash and zsh). go.toml sets the same for mise; set here too so the shell has
# them before mise's hook first runs

# GOPATH is DATA (the module cache, `go install`'s binaries), not ~/go
export GOPATH="$XDG_DATA_HOME/go"
# `go install` puts binaries in GOPATH/bin, as ruby's local gems go in $XDG_DATA_HOME/gems/bin:
# ~/.local/bin is anfs's
export GOBIN="$GOPATH/bin"
ensure_path "$GOBIN"
