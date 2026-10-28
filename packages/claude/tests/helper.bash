# Shared setup for stack/claude's tests: the adapter (hook) and the settings writer (settings).
#
# Both source core's libraries and the hook runs core's wsm, so the tests need a core checkout:
# ANFS_TEST_LIB's (stack's convention: a core checkout's lib/anfs), else the core checkout beside
# this stack one (a job's worktrees, or anfs-dev's clones), else the installed libraries' source.
# Every test runs the package's scripts linked into a HOME in the per-test temp directory, as ppm
# links them, with every XDG_* directory, the anfs and wsm homes, ANFSD_STATE_HOME and
# WSM_SPACES_HOME inside it; claude_guard fails the test if any would still resolve outside it.
# PATH holds the stubs, bash's, yq's and jq's directories and the system's; no real claude runs.

# not <command> [args...]: succeeds when the command fails. A bare `! command` fails a test only as
# its last line (bash's errexit ignores a negated command); a call to not fails it anywhere.
not() { ! "$@"; }

# The home this test was started with, before claude_setup moves it
_CLAUDE_REAL_HOME="${_CLAUDE_REAL_HOME:-$HOME}"

# Fail unless anfs's, wsm's and anfsd's directories, as paths.sh resolves them in
# this environment, are inside the test's temp directory (and so not under the real home)
claude_guard() {
  local tmp out d
  tmp=$(cd -P "$BATS_TEST_TMPDIR" && pwd -P)
  out=$(bash -c 'source "$HOME/.local/lib/anfs/paths.sh"
    printf "%s\n" "$ANFS_STATE_HOME" "$ANFS_CONFIG_HOME" "$ANFS_DATA_HOME" "$ANFS_CACHE_HOME" "$ANFS_SOURCES_HOME" \
      "${WSM_STATE_HOME:-$XDG_STATE_HOME/wsm}" "${WSM_CONFIG_HOME:-$XDG_CONFIG_HOME/wsm}" "$WSM_SPACES_HOME" \
      "$XDG_STATE_HOME" "$XDG_CONFIG_HOME" \
      "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "${XDG_RUNTIME_DIR:-}" "${ANFSD_STATE_HOME:-$XDG_STATE_HOME/anfsd}" "$HOME"') ||
    { echo "claude_guard: paths.sh failed" >&2; return 1; }
  while IFS= read -r d; do
    [[ -n "$d" ]] || continue
    if [[ ( "$d" != "$tmp"/* && "$d" != "$BATS_TEST_TMPDIR"/* ) || "$d" == "$_CLAUDE_REAL_HOME"/* ]]; then
      echo "claude_guard: $d is outside the test's temp directory: refusing to run" >&2
      return 1
    fi
  done <<< "$out"
}

claude_setup() {
  local lib="${ANFS_TEST_LIB:-}" beside="$BATS_TEST_DIRNAME/../../../../core/packages/anfs/home/.local/lib/anfs"
  if [[ -z "$lib" ]]; then
    if [[ -f "$beside/lease.sh" ]]; then lib="$beside"; else lib="$HOME/.local/lib/anfs"; fi
  fi
  [[ -f "$lib/lease.sh" ]] || skip "anfs's libraries are not at $lib"
  lib=$(cd -P "$lib" && pwd -P)
  # <core>/packages/anfs/home/.local/lib/anfs
  CORE=$(cd -P "$lib/../../../../../.." && pwd -P)
  WSM="$CORE/packages/wsm/home/.local/bin/wsm"
  [[ -x "$WSM" ]] || skip "no core checkout around $lib (its wsm)"
  PKG=$(cd -P "$BATS_TEST_DIRNAME/.." && pwd -P)
  SET="$PKG/home/.local/lib/anfs.d/claude/settings"
  mkdir -p "$BATS_TEST_TMPDIR/home" "$BATS_TEST_TMPDIR/state" "$BATS_TEST_TMPDIR/bin"
  # BATS_TEST_TMPDIR sits under /var on macOS, a symlink to /private/var; wsm canonicalizes the
  # targets it stores, so HOME has to be canonical too or nothing compares equal
  HOME=$(cd "$BATS_TEST_TMPDIR/home" && pwd -P)
  XDG_STATE_HOME=$(cd "$BATS_TEST_TMPDIR/state" && pwd -P)
  XDG_CONFIG_HOME="$HOME/.config" XDG_DATA_HOME="$HOME/.local/share" XDG_CACHE_HOME="$HOME/.cache"
  XDG_RUNTIME_DIR="$BATS_TEST_TMPDIR/run"
  mkdir -p -m 700 "$XDG_RUNTIME_DIR"
  ANFS_CONFIG_HOME="$XDG_CONFIG_HOME/anfs" ANFS_DATA_HOME="$XDG_DATA_HOME/anfs"
  ANFS_CACHE_HOME="$XDG_CACHE_HOME/anfs" ANFS_STATE_HOME="$XDG_STATE_HOME/anfs"
  WSM_CONFIG_HOME="$XDG_CONFIG_HOME/wsm" WSM_DATA_HOME="$XDG_DATA_HOME/wsm"
  WSM_CACHE_HOME="$XDG_CACHE_HOME/wsm" WSM_STATE_HOME="$XDG_STATE_HOME/wsm"
  # anfsd's STATE: the inbox summary the hook reads
  ANFSD_STATE_HOME="$XDG_STATE_HOME/anfsd" ANFSD_CONFIG_HOME="$XDG_CONFIG_HOME/anfsd"
  unset ANFS_WORK ANFS_WORK_SAID  # a person's ANFS_WORK never reaches a test (lib/anfs/work.sh)
  # Nothing of the session running the tests: no run's spool, no run, no claimed actor or role,
  # no Claude Code (CLAUDE*), no machine default for agent sessions (ANFS_ENABLED)
  unset ANFS_EVENTS_SPOOL ANFS_RUN ANFS_ACTOR ANFS_AS ANFS_SPACE AI_AGENT ANFS_TEST ANFS_LEASE_NOW "${!CLAUDE@}"
  unset ANFS_COORDINATOR ANFS_INBOX_HINT ANFS_ENABLED ANFS_DEBUG ANFS_JSON
  WSM_SPACES_HOME="$HOME/spaces"
  export HOME XDG_STATE_HOME XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_RUNTIME_DIR WSM_SPACES_HOME
  export ANFS_CONFIG_HOME ANFS_DATA_HOME ANFS_CACHE_HOME ANFS_STATE_HOME
  export WSM_CONFIG_HOME WSM_DATA_HOME WSM_CACHE_HOME WSM_STATE_HOME ANFSD_STATE_HOME ANFSD_CONFIG_HOME
  export ANFS_LOG=off   # no log file from tests (lib/anfs/log.sh)
  export ANFS_EVENTS=off   # no event log either (lib/anfs/events.sh); a test about events turns it on
  # What ppm links: core's libraries and wsm, this package's lib/anfs.d/claude (one link each)
  mkdir -p "$HOME/.local/lib/anfs.d" "$HOME/.local/bin"
  ln -s "$lib" "$HOME/.local/lib/anfs"
  ln -s "$PKG/home/.local/lib/anfs.d/claude" "$HOME/.local/lib/anfs.d/claude"
  ln -s "$WSM" "$HOME/.local/bin/wsm"
  HOOK="$HOME/.local/lib/anfs.d/claude/hook"
  export HOOK
  PATH="$BATS_TEST_TMPDIR/bin:$(dirname "$(command -v bash)"):$(dirname "$(command -v yq)"):$(dirname "$(command -v jq)"):/usr/bin:/bin:/usr/sbin:/sbin"
  export PATH
  claude_guard || return 1
  cd "$HOME" || return 1
}

wsm() { "$WSM" "$@"; }

# An anfs source <alias> (a local directory) registered in the test HOME's user.list and linked
# into the sources dir. Prints its path.
# Usage: mksource <alias>
mksource() {
  local dir="$BATS_TEST_TMPDIR/srcs/$1"
  mkdir -p "$dir/spaces" "$HOME/.config/anfs" "$HOME/.local/share/anfs/sources"
  ln -sfn "$dir" "$HOME/.local/share/anfs/sources/$1"
  printf '%s  %s\n' "$dir" "$1" >> "$HOME/.config/anfs/user.list"
  printf '%s\n' "$dir"
}

# Write a space definition, <source>/spaces/<path>/space.yml, from stdin. It gets a fresh id: line
# first, as wsm new writes one, unless the body has one or NOID=1.
# Usage: space_def <source> [path]  < body
space_def() {
  local d="$BATS_TEST_TMPDIR/srcs/$1/spaces${2:+/$2}" body id
  mkdir -p "$d"
  body=$(cat)
  if [[ "${NOID:-}" != 1 ]] && ! grep -q '^id:' <<< "$body"; then
    id=$(LC_ALL=C tr -dc 'a-z2-7' < /dev/urandom | head -c 10 || true)
    body="id: $id"$'\n'"$body"
  fi
  printf '%s\n' "$body" > "$d/space.yml"
}
