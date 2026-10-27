#!/usr/bin/env bats
# lib/claude/anfs/settings (agents/06b2 and the status line; moved here from core/wsm's
# claude-settings.bats by agents/06's to-stack). The coordinator's hooks go into the person's
# ~/.claude/settings.json (the test's HOME), written by this package's install.sh (post_install:
# settings install) and taken out by its removal: the package owns only the handlers whose command
# is its adapter (~/.local/lib/claude/anfs/hook) and merges them in, keeping everything else;
# idempotent; not JSON or a link refused; settings status warns when they are wrong. Its
# statusLine is on by default (CLAUDE_ANFS_STATUSLINE=off leaves it out), never over the person's
# own; settings config set|unset rewrites the file. jq only checks the JSON here.
# Run: bats packages/claude/tests/settings.bats

load helper

setup() {
  claude_setup
  H="$HOOK"
  S="$HOME/.claude/settings.json"
  export H
}

settings() { "$SET" "$@"; }

# the hook handlers of <event>, one line each: their args joined, then the flags
handlers() {
  jq -r --arg e "$1" '.hooks[$e] // [] | .[] | .hooks[] |
    [(.command | if . == env.H then "H" else . end), ((.args // []) | join(" ")),
     (if .asyncRewake then "rewake" else "sync" end), (.timeout | tostring)] | join("|")' "${2:-$S}"
}

# --- ~/.claude/settings.json -------------------------------------------------------------------

@test "install: the five entries, the absolute path, exec form, asyncRewake with a day's timeout" {
  run settings install
  [ "$status" -eq 0 ]
  [[ "$output" == "claude settings: written (~/.claude/settings.json: the coordinator's hooks and the status line)" ]] || { echo "$output"; false; }
  [[ "$H" == /* && "$H" == "$HOME/.local/lib/claude/anfs/hook" ]]
  [ "$(handlers SessionStart)" = $'H|session-start|sync|10\nH|listen --max 86340|rewake|86400' ]
  [ "$(handlers Stop)" = "H|listen --max 86340|rewake|86400" ]
  [ "$(handlers UserPromptSubmit)" = "H|prompt|sync|5" ]
  [ "$(handlers SessionEnd)" = "H|session-end|sync|3" ]
  # exec form: command and args, every one a command hook
  [ "$(jq '[.hooks[][] | .hooks[] | select(.type != "command" or (.args | type) != "array")] | length' "$S")" -eq 0 ]
  # idempotent: the same bytes, nothing written
  local sum
  sum=$(cksum < "$S")
  run settings install
  [[ "$output" == "claude settings: up to date"* ]]
  [ "$(cksum < "$S")" = "$sum" ]
  run settings status
  [ "$status" -eq 0 ] && [ "$output" = "claude settings: ok (~/.claude/settings.json)" ]
}

@test "a person's settings are kept: keys, their own hooks, their handlers first in our events; remove takes only ours" {
  mkdir -p "$HOME/.claude"
  cat > "$S" <<'EOF'
{
  "permissions": {"allow": ["Bash(ls:*)"], "deny": []},
  "env": {"FOO": "bar"},
  "hooks": {
    "PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "/usr/local/bin/guard", "args": ["x"]}]}],
    "Stop": [{"hooks": [{"type": "command", "command": "/opt/herdr/hook", "timeout": 7}]}]
  },
  "model": "opus"
}
EOF
  printf '{"permissions":{"allow":["Bash(rm:*)"]}}\n' > "$HOME/.claude/settings.local.json"
  local before_local
  before_local=$(cat "$HOME/.claude/settings.local.json")
  settings install >/dev/null
  [ "$(jq -c .permissions "$S")" = '{"allow":["Bash(ls:*)"],"deny":[]}' ]
  [ "$(jq -r .env.FOO "$S")" = bar ] && [ "$(jq -r .model "$S")" = opus ]
  [ "$(handlers PreToolUse)" = "/usr/local/bin/guard|x|sync|null" ]
  [ "$(handlers Stop)" = $'/opt/herdr/hook||sync|7\nH|listen --max 86340|rewake|86400' ]
  [ "$(cat "$HOME/.claude/settings.local.json")" = "$before_local" ]
  # an older entry of ours (another path to the hook) is outdated, then replaced
  jq '.hooks.Stop += [{"hooks":[{"type":"command","command":"/old/home/.local/lib/claude/anfs/hook","args":["listen"]}]}]' "$S" > "$S.n" && mv "$S.n" "$S"
  run settings status
  [ "$status" -eq 1 ]
  [[ "$output" == *"~/.claude/settings.json: stack/claude's Claude Code hooks are outdated: ppm install stack/claude writes them"* ]] || { echo "$output"; false; }
  settings install >/dev/null
  [ "$(handlers Stop)" = $'/opt/herdr/hook||sync|7\nH|listen --max 86340|rewake|86400' ]
  # remove: our hooks out, the person's file stays
  run settings remove
  [ "$status" -eq 0 ] && [[ "$output" == *"taken out of ~/.claude/settings.json"* ]]
  [ "$(jq -r '.hooks | keys | join(",")' "$S")" = PreToolUse,Stop ]
  [ "$(handlers Stop)" = "/opt/herdr/hook||sync|7" ]
  [ "$(jq -r .model "$S")" = opus ]
  [ "$(cat "$HOME/.claude/settings.local.json")" = "$before_local" ]
  # without our hooks: nothing to warn about, nothing to remove
  run settings status
  [ "$status" -eq 0 ] && [ "$output" = "claude settings: missing (~/.claude/settings.json)" ]
  local sum
  sum=$(cksum < "$S")
  run settings remove
  [ "$status" -eq 0 ] && [ -z "$output" ] && [ "$(cksum < "$S")" = "$sum" ]
}

@test "remove: a file with only our hooks goes; ~/.claude stays" {
  settings install >/dev/null
  settings remove >/dev/null
  [ ! -e "$S" ] && [ -d "$HOME/.claude" ]
}

@test "not a JSON object, or a link, is refused, saying so; status warns" {
  mkdir -p "$HOME/.claude"
  printf '{ "permissions": oops\n' > "$S"
  run settings install
  [ "$status" -ne 0 ]
  [[ "$output" == *"settings.json is not a JSON object"* ]]
  [ "$(cat "$S")" = '{ "permissions": oops' ]
  run settings status
  [ "$status" -eq 1 ] && [[ "$output" == *"is not a JSON object"* ]]
  run settings remove
  [ "$status" -eq 0 ] && [ "$(cat "$S")" = '{ "permissions": oops' ]
  printf '[1]\n' > "$S"
  run settings install
  [ "$status" -ne 0 ]
  printf '{}\n' > "$BATS_TEST_TMPDIR/real.json"
  rm "$S" && ln -s "$BATS_TEST_TMPDIR/real.json" "$S"
  run settings install
  [ "$status" -ne 0 ]
  [[ "$output" == *"settings.json is a link"*"one owner"* ]] || { echo "$output"; false; }
  [ "$(cat "$BATS_TEST_TMPDIR/real.json")" = '{}' ]
  run settings status
  [ "$status" -eq 1 ] && [[ "$output" == *"is a link"* ]]
}

@test "stack/claude's install.sh: post_install writes the hooks, post_remove takes them out" {
  run bash -c 'ppm_fail() { echo "FAIL $*"; return 1; }; user_message() { :; }
    source "$1/install.sh"; post_install' _ "$PKG"
  [ "$status" -eq 0 ] && [[ "$output" != *FAIL* ]] || { echo "$output"; false; }
  [ "$(handlers Stop)" = "H|listen --max 86340|rewake|86400" ]
  run bash -c 'user_message() { :; }; source "$1/install.sh"; post_remove' _ "$PKG"
  [ "$status" -eq 0 ]
  [ ! -e "$S" ]
  # a refused file: post_install says so through ppm_fail, and goes on
  mkdir -p "$HOME/.claude"
  printf '[1]\n' > "$S"
  run bash -c 'ppm_fail() { echo "FAIL $*"; return 1; }; user_message() { :; }
    source "$1/install.sh"; post_install' _ "$PKG"
  [ "$status" -eq 0 ] && [[ "$output" == *"FAIL stack/claude could not write its Claude Code hooks (above): fix that, then ppm install stack/claude"* ]] || { echo "$output"; false; }
}

# --- the status line ------------------------------------------------------------------------------

sl() { jq -c '.statusLine // empty' "$S"; }

@test "the status line: on by default, quoted for a shell; off takes ours out and keeps the hooks; remove takes it out" {
  settings install >/dev/null
  [ "$(sl)" = "{\"type\":\"command\",\"command\":\"'$H' statusline\"}" ] || { sl; false; }
  # the command runs in a shell: outside a space it prints nothing and exits 0
  run sh -c "$(jq -r .statusLine.command "$S")" < <(printf '{"session_id":"s1","cwd":"%s"}' "$HOME")
  [ "$status" -eq 0 ] && [ -z "$output" ]
  run settings install
  [[ "$output" == "claude settings: up to date"* ]]
  # moved inside the file by someone else: still ours, still up to date
  jq '{statusLine} + del(.statusLine)' "$S" > "$S.n" && mv "$S.n" "$S"
  run settings install
  [[ "$output" == "claude settings: up to date"* ]] || { echo "$output"; false; }
  run env CLAUDE_ANFS_STATUSLINE=off "$SET" install
  [ "$output" = "claude settings: written (~/.claude/settings.json: the coordinator's hooks)" ] || { echo "$output"; false; }
  [ -z "$(sl)" ] && [ "$(handlers Stop)" = "H|listen --max 86340|rewake|86400" ]
  run env CLAUDE_ANFS_STATUSLINE=maybe "$SET" install
  [[ "$output" == *"CLAUDE_ANFS_STATUSLINE is on or off, not 'maybe': taken as off"* ]]
  [ -z "$(sl)" ]
  # the setting changed by hand: status says the file is outdated
  run settings status
  [ "$status" -eq 1 ] && [[ "$output" == *"outdated: ppm install stack/claude writes them"* ]]
  settings install >/dev/null
  [ -n "$(sl)" ]
  run settings remove
  [ "$status" -eq 0 ] && [ ! -e "$S" ]
}

@test "a person's statusLine is never touched: install says how to compose; off and remove leave it" {
  mkdir -p "$HOME/.claude"
  printf '{"statusLine":{"type":"command","command":"~/.claude/sl.sh","padding":1},"model":"opus"}\n' > "$S"
  local mine='{"type":"command","command":"~/.claude/sl.sh","padding":1}'
  run settings install
  [ "$status" -eq 0 ]
  [[ "$output" == *"claude settings: statusLine is yours (~/.claude/sl.sh): kept; for the coordinator's line, have it also run '$H' statusline with the same stdin and print what that prints"* ]] || { echo "$output"; false; }
  [[ "$output" == *"written (~/.claude/settings.json: the coordinator's hooks)" ]]
  [ "$(sl)" = "$mine" ]
  run env CLAUDE_ANFS_STATUSLINE=off "$SET" install
  [[ "$output" != *"statusLine is yours"* ]] && [ "$(sl)" = "$mine" ]
  settings remove >/dev/null
  [ "$(jq -c . "$S")" = '{"statusLine":'"$mine"',"model":"opus"}' ]
}

@test "settings config set|unset CLAUDE_ANFS_STATUSLINE rewrites the settings at once; the environment still wins" {
  settings install >/dev/null
  run settings config set CLAUDE_ANFS_STATUSLINE=off
  [ "$status" -eq 0 ]
  [[ "$output" == *"claude settings: written (~/.claude/settings.json: the coordinator's hooks)"* ]] || { echo "$output"; false; }
  [ -z "$(sl)" ]
  [ "$(cat "$XDG_CONFIG_HOME/claude-anfs/claude-anfs.local.env" | grep -c '^CLAUDE_ANFS_STATUSLINE=off$')" -eq 1 ]
  # install.sh's settings install reads it too
  settings install >/dev/null
  [ -z "$(sl)" ]
  run settings config get CLAUDE_ANFS_STATUSLINE
  [ "$output" = off ]
  run settings config unset CLAUDE_ANFS_STATUSLINE
  [[ "$output" == *"the coordinator's hooks and the status line"* ]] || { echo "$output"; false; }
  [ -n "$(sl)" ]
  run env CLAUDE_ANFS_STATUSLINE=on "$SET" config set CLAUDE_ANFS_STATUSLINE=off
  [[ "$output" == *"is set in the environment"* ]]
  [ -n "$(sl)" ]
  # a name that is not a setting is refused, and the file left alone
  local sum
  sum=$(cksum < "$S")
  run settings config set CLAUDE_ANFS_OTHER=1
  [ "$status" -eq 64 ] && [ "$(cksum < "$S")" = "$sum" ]
}

@test "settings: an unknown command is a usage error; help names install, remove, status and config" {
  run settings bogus
  [ "$status" -eq 64 ]
  run settings help
  [ "$status" -eq 0 ]
  [[ "$output" == *"install"* && "$output" == *"remove"* && "$output" == *"status"* && "$output" == *"config"* ]]
  [ ! -e "$S" ]
}
