# go

Go, installed by mise (`go = "latest"` in `.config/mise/conf.d/go.toml`), and gopls for nvim
(mason installs it).

It is here to build `anfsd` (anfs-io/runtime's `go/`); anfs-dev's `dev` package depends on it.
Users of anfs get prebuilt binaries and never need it.

## Where things go

- `GOPATH` is `~/.local/share/go` (DATA: the module cache and what `go install` fetches), never
  `~/go`.
- `GOBIN` is `$GOPATH/bin`, on PATH; `~/.local/bin` stays anfs's.

Both are set in `go.toml`'s `[env]` (for `mise exec` and hooks) and in `.config/sh/go.sh` (the
bash and zsh rc).

## Platforms

macOS and Linux (Debian, Fedora): mise downloads go.dev's binaries, so nothing comes from brew or
the distro.

```bash
ppm install go
go version
```

Tests: `bats packages/go/tests </dev/null`.
