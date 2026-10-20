# git

git, gh and git-filter-repo; aliases and helpers in `git.zsh`, nvim's git plugins, a global
ignore file.

## Commands

- `git account add [--host HOST] [--user USER]` — record your account at a git host (git's global
  `account.<host>.user`) and see that your ssh key is on it; gh adds it on github.com when signed
  in, else the key and the host's settings URL are printed. `-i` asks for both.
- `git account list` — `ACCOUNT STATUS KEYS`: each account, and whether a key here is on it.
- `git account remove <host>` — forget the account (asks; `-y`). Keys stay.
