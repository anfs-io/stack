# git

# --- anfs onboard (the contract: core/ppm's lib/ppm/onboard.sh) ---------------------------------
#   identity   your git name and email
#   github     sign in with gh, and put your ssh key (the key step's, when there is one) on your account
#   publish    your git config into your own repo, and that repo onto GitHub when asked (--repo new)

# gh's token the way the gh wrapper finds it in a shell (git.zsh): fnox reads ~/.config/fnox/gh.toml
_git_gh_env() {
  local file="$XDG_CONFIG_HOME/fnox/gh.toml"
  [[ -z "${GH_TOKEN:-}" && -f "$file" ]] && command -v fnox >/dev/null 2>&1 || return 0
  eval "$(fnox export --config "$file" 2>/dev/null)" || true
}

_git_gh_authed() {
  gh auth status >/dev/null 2>&1 && return 0
  _git_gh_env
  [[ -n "${GH_TOKEN:-}" ]] && gh auth status >/dev/null 2>&1
}

_git_gh_has_key() {
  local blob keys
  blob=$(awk '{print $2}' <<< "$1")
  keys=$(gh ssh-key list 2>/dev/null || true)
  grep -qF -- "$blob" <<< "$keys"
}

_git_fingerprint() { ssh-keygen -lf /dev/stdin <<< "$1" 2>/dev/null | awk '{print $2}'; }

onboard_identity_detect() {
  local name email want_name want_email
  name=$(git config --global user.name 2>/dev/null || true)
  email=$(git config --global user.email 2>/dev/null || true)
  want_name=$(onboard_opt name) want_email=$(onboard_opt email)
  if [[ -n "$name" && -n "$email" && "${want_name:-$name}" == "$name" && "${want_email:-$email}" == "$email" ]]; then
    onboard_set name "$name"
    onboard_set email "$email"
    onboard_detail "$name <$email>"
    return 0
  fi
  onboard_detail "git has no user.name and user.email"
  [[ -z "$name$email" ]] || onboard_detail "git has '$name <$email>'"
  return 1
}

onboard_identity() {
  local name email config="$XDG_CONFIG_HOME/git/config"
  ! onboard_identity_detect || return 0
  onboard_ask name "Your name, for git commits" "$(git config --global user.name 2>/dev/null || true)"
  name="$REPLY"
  onboard_ask email "Your email, for git commits" "$(git config --global user.email 2>/dev/null || true)"
  email="$REPLY"
  # git writes ~/.gitconfig unless this file exists. Here a package can own it (the publish step).
  if [[ ! -e "$HOME/.gitconfig" && ! -e "$config" ]]; then
    mkdir -p "${config%/*}"
    : > "$config"
  fi
  git config --global user.name "$name"
  git config --global user.email "$email"
  onboard_identity_detect
}

onboard_github_detect() {
  local login pubkey
  command -v gh >/dev/null 2>&1 || { onboard_detail "gh is not installed"; return 1; }
  _git_gh_authed || { onboard_detail "not signed in to GitHub"; return 1; }
  login=$(gh api user -q .login 2>/dev/null || true)
  [[ -z "$login" ]] || onboard_set gh_login "$login"
  pubkey=$(onboard_get pubkey)
  if [[ -n "$pubkey" ]] && ! _git_gh_has_key "$pubkey"; then
    onboard_detail "${login:-signed in}; your ssh key is not on the account"
    return 1
  fi
  onboard_detail "${login:-signed in}${pubkey:+, ssh key on the account}"
}

onboard_github() {
  local pubkey
  ! onboard_github_detect || return 0
  command -v gh >/dev/null 2>&1 || return 1

  if ! _git_gh_authed; then
    [[ -t 0 ]] || anfs_die "not signed in to GitHub: run 'gh auth login' (it opens a browser) or set GH_TOKEN, then run this again"
    onboard_propose "Sign in to GitHub in your browser (no account yet: https://github.com/signup)" || return 1
    # admin:public_key is what lets gh add your ssh key below
    gh auth login --hostname github.com --git-protocol ssh --skip-ssh-key --web --scopes admin:public_key ||
      anfs_die "gh auth login did not finish"
  fi

  pubkey=$(onboard_get pubkey)
  if [[ -n "$pubkey" ]] && ! _git_gh_has_key "$pubkey"; then
    if onboard_propose "Add your ssh key ($(_git_fingerprint "$pubkey")) to your GitHub account"; then
      printf '%s\n' "$pubkey" | gh ssh-key add - --title "$(hostname -s)" ||
        ppm_fail "gh could not add the key; its token may lack the scope: gh auth refresh -s admin:public_key"
    fi
  fi
  onboard_github_detect
}

# True when your git config is a plain file no package owns, and your repo has no git package
_git_config_loose() {
  local config="$XDG_CONFIG_HOME/git/config"
  [[ -f "$config" && ! -L "$config" && ! -d "$1/packages/git" ]]
}

onboard_publish_detect() {
  local dir url
  dir=$(onboard_user_repo)
  if [[ -z "$dir" ]]; then
    onboard_state n/a
    onboard_detail "no repo of your own yet (the repo step)"
    return 0
  fi
  if _git_config_loose "$dir"; then
    onboard_detail "your git config is not in your repo"
    return 1
  fi
  url=$(onboard_user_repo_url)
  case "$url" in
    git@*|*://*) onboard_detail "$url" ;;
    *)
      if [[ "$(onboard_opt repo)" == new ]]; then
        onboard_detail "your repo is not on GitHub"
        return 1
      fi
      onboard_detail "your repo is on this machine only (--repo new puts it on GitHub)"
      ;;
  esac
}

onboard_publish() {
  local dir url login list name=anfs config="$XDG_CONFIG_HOME/git/config"
  ! onboard_publish_detect || return 0
  dir=$(onboard_user_repo)

  if _git_config_loose "$dir" && onboard_propose "Keep your git config in your repo (${dir/#$HOME/~}/packages/git)"; then
    mkdir -p "$dir/packages/git"
    printf 'version: 0.1.0\nauthor: %s\n' "$(id -un)" > "$dir/packages/git/package.yml"
    # Moves the file into the package and stows it back from there
    if "$BIN_DIR/ppm" file add "$PPM_USER_REPO_ALIAS/git" "$config"; then
      onboard_commit "$dir" "git: my config"
    else
      ppm_fail "ppm file add $PPM_USER_REPO_ALIAS/git $config failed; your git config is where it was"
    fi
  fi

  url=$(onboard_user_repo_url)
  if [[ "$url" != git@* && "$url" != *://* && "$(onboard_opt repo)" == new ]]; then
    _git_gh_authed || { onboard_detail "not signed in to GitHub (the github step), so your repo stays local"; return 1; }
    login=$(onboard_get gh_login)
    [[ -n "$login" ]] || login=$(gh api user -q .login 2>/dev/null || true)
    [[ -n "$login" ]] || anfs_die "gh does not say who you are (gh api user)"
    url="git@github.com:$login/$name.git"
    onboard_propose "Create the private repo github.com/$login/$name and push ${dir/#$HOME/~} to it" || return 1
    onboard_commit "$dir" "anfs onboard: the user source"
    gh repo create "$login/$name" --private --source "$dir" --remote origin --push ||
      anfs_die "gh could not create $login/$name. If it exists already: anfs src remove $PPM_USER_REPO_ALIAS, move ${dir/#$HOME/~} away, and anfs onboard repo --repo $url"
    # Listed by its URL from here on; written through the link, into the repo's own copy
    list=$(awk -v dir="$dir" -v url="$url" -v alias="$PPM_USER_REPO_ALIAS" \
      '$1 == dir && $NF == alias { print url "  " alias; next } { print }' "$ANFS_USER_LIST")
    printf '%s\n' "$list" > "$ANFS_USER_LIST"
    onboard_commit "$dir" "user.list: the user source is $url"
    git -C "$dir" push -q || ppm_fail "git push failed in $dir; push it by hand"
  fi
  onboard_publish_detect
}
