#!/usr/bin/env bats
# lib/claude/anfs/hook, the Claude Code adapter (agents/06b, 06b2; moved here from core/anfs's
# claude-hook.bats by agents/06's to-stack), fed fake hook input; the sessions inherit the test's
# WSM_SPACES_HOME, as Claude Code inherits sh/wsm.sh's. A fake Claude Code is a copy of bash named
# claude (so ps says claude on macOS and Linux) running a driver that runs the hook as its child on
# request through two FIFOs, alive until the test ends it: one session's hooks share its pid, as
# Claude Code's do. No real Claude, no bus: wsm and the lease library from the core checkout
# (helper.bash), the inbox summary a fixture. The helper's isolation and guard (every XDG_*,
# ANFS_*_HOME, WSM_*_HOME and ANFSD_STATE_HOME in the test's temp directory).
# anfs: none (or ANFS_ENABLED=none, a space saying nothing) silences every entry (agents/06's anfs-key).
# The SessionStart pair test is tagged slow (over 10 s) and the idle bound timing.
# Run: bats packages/claude/tests/hook.bats

load helper

setup() {
  claude_setup
  T="$BATS_TEST_TMPDIR"
  cp "$(command -v bash)" "$T/bin/claude"
  export USER=tester TMPDIR="$T" ANFS_EVENTS=on
  # the fake clock (lease.sh's): the real time until a test writes $T/clock; every session's
  # environment has it, as Claude Code's hooks inherit its environment
  export ANFS_TEST=1 ANFS_LEASE_NOW="@$T/clock"
  mksource acme >/dev/null
  space_def acme <<<$'id: acmeroot22\ncoordinator: claude'
  wsm install acme >/dev/null
  SP="$WSM_SPACES_HOME/acme"
  R="$WSM_SPACES_HOME"
  L="$XDG_STATE_HOME/anfs/leases/acmeroot22/coordinator.json"
  EV="$XDG_STATE_HOME/anfs/events/acmeroot22"
  SUM="$ANFSD_STATE_HOME/inbox/summary.json"
  cat > "$T/driver" <<'EOF'
exec 3<"$1" 4>"$2"
declare -A bg=()
while IFS=$'\t' read -r -u3 cmd args input out; do
  case "$cmd" in
    run) "$HOOK" $args < "$input" > "$out" 2> "$out.err" 3<&- 4>&-; echo "$?" >&4 ;;
    bg) "$HOOK" $args < "$input" > "$out" 2> "$out.err" 3<&- 4>&- & bg[$out]=$!; echo "$!" >&4 ;;
    wait) wait "${bg[$out]}"; echo "$?" >&4 ;;
    *) exit 0 ;;
  esac
done
EOF
  SESSIONS=()
  cd "$SP"
}

teardown() {
  local n
  for n in ${SESSIONS[@]+"${SESSIONS[@]}"}; do
    [[ -f "$T/s-$n/pid" ]] && kill -9 "$(cat "$T/s-$n/pid")" 2>/dev/null || true
  done
}

# The id of fake session <n>: <n> eight times, then a fixed tail (its actor: claude:<n x 8>)
sid() { printf '%s-1111-4222-8333-444455556666' "$(printf "$1%.0s" 1 2 3 4 5 6 7 8)"; }

# A hook input: input <file> <session> <event> [key=value...] (cwd: the space unless given)
input() {
  local f="$1" s="$2" e="$3" kv cwd="$SP" extra=""
  shift 3
  for kv in "$@"; do
    case "$kv" in cwd=*) cwd="${kv#cwd=}" ;; *) extra+=",\"${kv%%=*}\":\"${kv#*=}\"" ;; esac
  done
  printf '{"session_id":"%s","transcript_path":"/x/t.jsonl","cwd":"%s","permission_mode":"default","hook_event_name":"%s"%s}\n' \
    "$(sid "$s")" "$cwd" "$e" "$extra" > "$f"
}

# session <n>: start fake Claude Code <n>; its pid in $T/s-<n>/pid
session() {
  local d="$T/s-$1" w r
  mkdir -p "$d"
  mkfifo "$d/req" "$d/rep"
  "$T/bin/claude" "$T/driver" "$d/req" "$d/rep" 3>&- &
  echo "$!" > "$d/pid"
  exec {w}>"$d/req" {r}<"$d/rep"
  eval "W_$1=$w R_$1=$r"
  SESSIONS+=("$1")
}
spid() { cat "$T/s-$1/pid"; }
# hook <n> <entry and args> <event> [key=value...]: run the hook in session n; HOUT, HERR, HRC
hook() {
  local n="$1" args="$2" e="$3" w r
  shift 3
  input "$T/s-$n/in.$e" "$n" "$e" "$@"
  eval "w=\$W_$n r=\$R_$n"
  printf 'run\t%s\t%s\t%s\n' "$args" "$T/s-$n/in.$e" "$T/s-$n/out" >&"$w"
  IFS= read -r HRC <&"$r"
  HOUT=$(cat "$T/s-$n/out") HERR=$(cat "$T/s-$n/out.err")
}
# hook_bg <n> <tag> <entry and args> <event> [key=value...]: in the background; the hook's pid
# into BGPID, its output in $T/s-<n>/<tag>; hook_wait <n> <tag>: its exit status into HRC
hook_bg() {
  local n="$1" tag="$2" args="$3" e="$4" w r
  shift 4
  input "$T/s-$n/in.$tag" "$n" "$e" "$@"
  eval "w=\$W_$n r=\$R_$n"
  printf 'bg\t%s\t%s\t%s\n' "$args" "$T/s-$n/in.$tag" "$T/s-$n/$tag" >&"$w"
  IFS= read -r BGPID <&"$r"
}
hook_wait() {
  local w r
  eval "w=\$W_$1 r=\$R_$1"
  printf 'wait\t-\t-\t%s\n' "$T/s-$1/$2" >&"$w"
  IFS= read -r HRC <&"$r"
}
# end <n>: the session's process dies (kill -9: no SessionEnd)
die() { kill -9 "$(spid "$1")"; wait "$(spid "$1")" 2>/dev/null || true; }

lease_field() { sed -E 's/.*"'"$1"'":"?([^",}]*).*/\1/' "$L" 2>/dev/null; }
events_of() { cat "$EV"/*.jsonl 2>/dev/null | grep -c "\"type\":\"io.anfs.$1\"" || true; }
emit() { ANFS_ACTOR=shell:other bash -c 'source "$HOME/.local/lib/anfs/bash.sh"; for l in paths log files events; do source "$HOME/.local/lib/anfs/$l.sh"; done; cd "$1"; shift; anfs_emit "$@"' _ "$SP" "$@"; }

# --- claiming --------------------------------------------------------------------------------

@test "session-start in a space claims and prints the brief; a second session names the holder and does not claim" {
  session a
  hook a session-start SessionStart source=startup
  [ "$HRC" -eq 0 ] || { echo "rc=$HRC out=$HOUT err=$HERR"; false; }
  [[ "$HOUT" == "anfs: this session is the coordinator of acme (acme/coordinator, space acmeroot22)."* ]]
  [[ "$HOUT" == *"anfs inbox"* && "$HOUT" == *"ANFS_COORDINATOR=off claude"* ]]
  [ "$(lease_field kind)" = claude ]
  [ "$(lease_field pid)" = "$(spid a)" ]
  [ "$(lease_field session)" = "$(sid a)" ]
  [ "$(lease_field actor)" = claude:aaaaaaaa ]
  [ "$(events_of lease.claimed)" -eq 1 ]
  grep -q '"actor":"claude:aaaaaaaa"' "$EV"/*.jsonl
  local claim
  claim=$(lease_field claim)
  session b
  hook b session-start SessionStart source=startup
  [ "$HRC" -eq 0 ]
  [[ "$HOUT" == "anfs: the coordinator of acme is claude:aaaaaaaa (another session, working, since "*"); this session does not listen." ]]
  [ "$(lease_field claim)" = "$claim" ]
  [ "$(events_of lease.claimed)" -eq 1 ]
  # compact: the brief again (the old context is gone), the same claim, no event
  hook a session-start SessionStart source=compact
  [[ "$HOUT" == "anfs: this session is still the coordinator of acme"* ]]
  [ "$(lease_field claim)" = "$claim" ]
  [ "$(events_of lease.claimed)" -eq 1 ]
  # prompt as the holder: nothing to say
  hook a prompt UserPromptSubmit prompt=hi
  [ "$HRC" -eq 0 ] && [ -z "$HOUT" ]
  hook b prompt UserPromptSubmit prompt=hi
  [ -z "$HOUT" ]
}

@test "prompt takes a dead holder's lease: the takeover brief, lease.expired then lease.claimed" {
  session a
  hook a session-start SessionStart source=startup
  session b
  die a
  hook b prompt UserPromptSubmit prompt=hello
  [ "$HRC" -eq 0 ]
  [[ "$HOUT" == "anfs: this session is now the coordinator of acme (acme/coordinator, space acmeroot22) (taken from claude:aaaaaaaa: dead)."* ]]
  [ "$(lease_field pid)" = "$(spid b)" ]
  cat "$EV"/*.jsonl | grep -q '"type":"io.anfs.lease.expired".*"why":"dead"'
  cat "$EV"/*.jsonl | grep -q '"type":"io.anfs.lease.claimed".*"from":"dead".*"previous":"claude:aaaaaaaa"'
}

@test "a session that lost the lease says so once; released leases are taken from released" {
  session a
  hook a session-start SessionStart source=startup
  session b
  hook b session-start SessionStart source=startup
  # a's lease expires (working's two hours pass on the fake clock); b's next prompt takes it
  printf '%s\n' "$(( EPOCHSECONDS + 3 * 3600 ))" > "$T/clock"
  hook b prompt UserPromptSubmit prompt=x
  [[ "$HOUT" == *"is now the coordinator"*"(taken from claude:aaaaaaaa: expired)"* ]]
  hook a prompt UserPromptSubmit prompt=x
  [[ "$HOUT" == "anfs: this session is no longer the coordinator of acme (claude:bbbbbbbb took it at "*")." ]]
  hook a prompt UserPromptSubmit prompt=x
  [ -z "$HOUT" ]
  # b ends (clear): released, reason clear; a takes it from released at its next prompt
  hook b session-end SessionEnd reason=clear
  [ "$HRC" -eq 0 ]
  cat "$EV"/*.jsonl | grep -q '"type":"io.anfs.lease.released".*"reason":"clear"'
  [ "$(lease_field state)" = free ]
  [ ! -e "$XDG_STATE_HOME/anfs/claude/$(sid b).lease" ]
  hook a prompt UserPromptSubmit prompt=x
  [[ "$HOUT" == *"is now the coordinator"*"(taken from claude:bbbbbbbb: released)"* ]]
  hook a session-end SessionEnd reason=prompt_input_exit
  cat "$EV"/*.jsonl | grep -q '"type":"io.anfs.lease.released".*"reason":"session-end"'
}

@test "no claim and exit 0: outside a space, ANFS_COORDINATOR=off, ANFS_RUN, a subagent, no Claude ancestor" {
  session a
  mkdir -p "$T/elsewhere"
  hook a session-start SessionStart source=startup cwd="$T/elsewhere"
  [ "$HRC" -eq 0 ] && [ -z "$HOUT" ] && [ ! -e "$L" ]
  hook a session-start SessionStart source=startup agent_id=sub1 agent_type=Explore
  [ "$HRC" -eq 0 ] && [ -z "$HOUT" ] && [ ! -e "$L" ]
  # the environment is the session's: a new fake Claude for each
  ANFS_COORDINATOR=off session b
  hook b session-start SessionStart source=startup
  [ "$HRC" -eq 0 ] && [ -z "$HOUT" ] && [ ! -e "$L" ]
  hook b prompt UserPromptSubmit prompt=x
  [ -z "$HOUT" ] && [ ! -e "$L" ]
  ANFS_RUN=019a0000-0000-7000-8000-000000000001 session c
  hook c session-start SessionStart source=startup
  [ "$HRC" -eq 0 ] && [ -z "$HOUT" ] && [ ! -e "$L" ]
  # run straight from the test: its parent is bats's bash, not claude; CLAUDE_PID is not trusted
  input "$T/in" z SessionStart source=startup
  CLAUDE_PID="$(spid a)" run "$HOOK" session-start < "$T/in"
  [ "$status" -eq 0 ] && [ -z "$output" ] && [ ! -e "$L" ]
  [ "$(events_of lease.claimed)" -eq 0 ]
  # no input at all
  run "$HOOK" prompt < /dev/null
  [ "$status" -eq 0 ] && [ -z "$output" ]
}

@test "the wrapper chain (claude, sh -c, the hook) finds claude; CLAUDE_PID naming another process is ignored" {
  input "$T/in" a SessionStart source=startup
  sleep 100 3>&- & local other=$!
  CLAUDE_PID="$other" "$T/bin/claude" -c 'echo $$ > "$2"; sh -c "\"\$HOOK\" session-start < \"\$1\"" sh "$1" > "$3"; rc=$?; sleep 30; exit $rc' claude \
    "$T/in" "$T/cpid" "$T/out" 3>&- &
  local c=$!
  local i
  for (( i = 0; i < 100; i++ )); do [[ -s "$T/out" ]] && break; sleep 0.1; done
  [[ "$(cat "$T/out")" == "anfs: this session is the coordinator of acme"* ]]
  [ "$(lease_field pid)" = "$(cat "$T/cpid")" ]
  kill "$c" "$other" 2>/dev/null || true
}

# --- the listener --------------------------------------------------------------------------------

# bats test_tags=slow
@test "the SessionStart pair in parallel yields one claim; events wake the listener (exit 2, the batch on stderr); Stop rearms" {
  session a
  hook_bg a l1 "listen --max 60" SessionStart source=startup
  local l1=$BGPID
  hook a session-start SessionStart source=startup
  [[ "$HOUT" == *"coordinator of acme"* ]]
  local i
  for (( i = 0; i < 100; i++ )); do [[ "$(lease_field state)" == listening ]] && break; sleep 0.1; done
  [ "$(lease_field state)" = listening ]
  [ "$(events_of lease.claimed)" -eq 1 ]
  emit report.filed r-7 title=broken
  hook_wait a l1
  [ "$HRC" -eq 2 ]
  [ -z "$(cat "$T/s-a/l1")" ]
  grep -q '^acme: 1 event since ' "$T/s-a/l1.err"
  grep -q 'report.filed  *r-7 .*broken' "$T/s-a/l1.err"
  [ "$(lease_field state)" = working ]
  # the turn that wake started ends: Stop listens again, the batch committed (not redelivered)
  hook_bg a l2 "listen --max 60" Stop stop_hook_active=false
  for (( i = 0; i < 100; i++ )); do [[ "$(lease_field state)" == listening ]] && break; sleep 0.1; done
  [ "$(lease_field state)" = listening ]
  # a newer listener (the next turn's Stop) takes over: the older ends without a wake (0)
  hook_bg a l3 "listen --max 60" Stop
  hook_wait a l2
  [ "$HRC" -eq 0 ] && [ -z "$(cat "$T/s-a/l2.err")" ]
  emit run.failed 019a-x rule=fix
  hook_wait a l3
  [ "$HRC" -eq 2 ]
  grep -q 'run.failed' "$T/s-a/l3.err"
  not grep -q 'r-7' "$T/s-a/l3.err"
}

@test "listen: a non-holder exits 0 at once; --max wakes with one line; the hook's timeout and the holder's death end it" {
  session a
  hook a session-start SessionStart source=startup
  session b
  hook b "listen --max 60" Stop
  [ "$HRC" -eq 0 ] && [ -z "$HOUT" ] && [ -z "$HERR" ]
  hook b "listen --max 60" SessionStart source=startup
  [ "$HRC" -eq 0 ]
  hook a "listen --max 2" Stop
  [ "$HRC" -eq 2 ]
  [[ "$HERR" == "anfs: no events for acme/coordinator in 2s; still listening (this turn's end listens again)." ]]
  # the hook's timeout: SIGTERM ends the listener with it, the lease back to working
  hook_bg a l1 "listen --max 60" Stop
  local i
  for (( i = 0; i < 100; i++ )); do [[ "$(lease_field state)" == listening ]] && break; sleep 0.1; done
  kill -TERM "$BGPID"
  hook_wait a l1
  [ "$HRC" -eq 0 ]
  for (( i = 0; i < 50; i++ )); do [[ "$(lease_field state)" == working ]] && break; sleep 0.1; done
  [ "$(lease_field state)" = working ]
  # the session's process dies with its listener running: both end within seconds, no wake
  hook_bg a l2 "listen --max 60" Stop
  local hp=$BGPID lp=""
  for (( i = 0; i < 100; i++ )); do [[ "$(lease_field state)" == listening ]] && break; sleep 0.1; done
  lp=$(pgrep -P "$hp" | head -n 1)
  [ -n "$lp" ]
  die a
  for (( i = 0; i < 50; i++ )); do kill -0 "$hp" 2>/dev/null || kill -0 "$lp" 2>/dev/null || break; sleep 0.1; done
  not kill -0 "$hp" 2>/dev/null
  not kill -0 "$lp" 2>/dev/null
  [ ! -s "$T/s-a/l2.err" ]
}

# bats test_tags=timing
@test "a waiting listen hook is idle: under 0.2 s of CPU in 5 s, with its listener" {
  session a
  hook a session-start SessionStart source=startup
  hook_bg a l1 "listen --max 60" Stop
  local hp=$BGPID i lp
  for (( i = 0; i < 100; i++ )); do [[ "$(lease_field state)" == listening ]] && break; sleep 0.1; done
  lp=$(pgrep -P "$hp" | head -n 1)
  [ -n "$lp" ]
  # centiseconds of CPU: /proc's utime and stime (Linux, 100 ticks a second), else ps's m:ss.cc (macOS)
  cpu() {
    if [[ -r "/proc/$1/stat" ]]; then awk '{ print $14 + $15 }' "/proc/$1/stat"
    else LC_ALL=C ps -o time= -p "$1" | awk -F'[:.]' '{ if (NF == 3) print ($1 * 60 + $2) * 100 + $3; else print (($1 * 60 + $2) * 60 + $3) * 100 + $4 }'; fi
  }
  local a1 a2 b1 b2
  a1=$(cpu "$hp") b1=$(cpu "$lp")
  sleep 5
  a2=$(cpu "$hp") b2=$(cpu "$lp")
  echo "hook $(( a2 - a1 ))cs listener $(( b2 - b1 ))cs"
  (( a2 - a1 + b2 - b1 < 20 ))
}

@test "arm: task: the brief tells the model to listen; the prompt says so when the listener is gone; listen does nothing" {
  space_def acme <<<$'id: acmeroot22\ncoordinator: {harness: claude, arm: task}'
  wsm install acme >/dev/null
  session a
  hook a session-start SessionStart source=startup
  local claim
  claim=$(lease_field claim)
  [[ "$HOUT" == *"run \`wsm listen --claim $claim coordinator\` with Bash run_in_background"* ]]
  hook a prompt UserPromptSubmit prompt=x
  [[ "$HOUT" == "anfs: the coordinator's listener is not running: start it again (Bash, in the background, in $SP): wsm listen --claim $claim coordinator" ]]
  # with a live listener: nothing
  ( cd "$SP" && exec "$WSM" listen --claim "$claim" --max 30s coordinator ) > /dev/null 2>&1 3>&- &
  local lp=$! i
  for (( i = 0; i < 100; i++ )); do [[ "$(lease_field state)" == listening ]] && break; sleep 0.1; done
  hook a prompt UserPromptSubmit prompt=x
  [ -z "$HOUT" ] || { echo "$HOUT"; cat "$L"; false; }
  kill "$lp" 2>/dev/null || true
  # the listen entries (in every settings file now) leave the listener to the model
  hook a "listen --max 60" Stop
  [ "$HRC" -eq 0 ] && [ -z "$HERR" ]
}

# --- the inbox line ------------------------------------------------------------------------------

summary() { mkdir -p "${SUM%/*}"; printf '%s\n' "$1" > "$SUM"; }

@test "the inbox line: from the summary, on change and every 30 minutes, ANFS_INBOX_HINT=off, nothing when nothing waits" {
  session a
  hook a session-start SessionStart source=startup
  hook a prompt UserPromptSubmit prompt=x
  [ -z "$HOUT" ]
  summary '{"v":1,"total":3,"spaces":{"acmeroot22":{"space":"acme","approvals":2,"unhandled":0,"oldest":"2026-10-24T10:00:00.000Z","items":["merge core +3 (r-20261024-2)","install core/pcm"]},"cnfs234567":{"space":"cnfs","approvals":0,"unhandled":1,"oldest":"2026-10-24T12:00:00.000Z","items":["dispatch report.filed r-9 for triage (held: queue)"]}}}'
  printf '%s\n' "$EPOCHSECONDS" > "$T/clock"
  hook a prompt UserPromptSubmit prompt=x
  [ "$HOUT" = "anfs inbox: 2 waiting here (merge core +3 (r-20261024-2), install core/pcm), 1 elsewhere: anfs inbox" ]
  hook a prompt UserPromptSubmit prompt=x
  [ -z "$HOUT" ]
  printf '%s\n' "$(( EPOCHSECONDS + 1801 ))" > "$T/clock"
  hook a prompt UserPromptSubmit prompt=x
  [[ "$HOUT" == "anfs inbox: 2 waiting here"* ]]
  # changed: printed at once; more than two: the count
  summary '{"v":1,"total":3,"spaces":{"acmeroot22":{"space":"acme","approvals":2,"unhandled":1,"oldest":"2026-10-24T10:00:00.000Z","items":["merge core +3 (r-20261024-2)","install \"core/pcm\""]}}}'
  hook a prompt UserPromptSubmit prompt=x
  [ "$HOUT" = 'anfs inbox: 3 waiting here (merge core +3 (r-20261024-2), install "core/pcm", +1 more): anfs inbox' ]
  # elsewhere only
  summary '{"v":1,"total":1,"spaces":{"cnfs234567":{"space":"cnfs","approvals":1,"unhandled":0,"oldest":"2026-10-24T10:00:00.000Z","items":["push core: origin main"]}}}'
  hook a prompt UserPromptSubmit prompt=x
  [ "$HOUT" = "anfs inbox: 1 waiting in other spaces: anfs inbox" ]
  # off for a session
  ANFS_INBOX_HINT=off session b
  hook b prompt UserPromptSubmit prompt=x
  [ -z "$HOUT" ]
  # nothing waits: nothing, and the next item is news again
  summary '{"v":1,"total":0,"spaces":{}}'
  hook a prompt UserPromptSubmit prompt=x
  [ -z "$HOUT" ]
  [ ! -e "$XDG_STATE_HOME/anfs/claude/$(sid a).inbox" ]
  # anfsd never ran: no file, no line
  rm -f "$SUM"
  hook a prompt UserPromptSubmit prompt=x
  [ "$HRC" -eq 0 ] && [ -z "$HOUT" ]
}

@test "coordinator: none: no claim, no listener, the inbox line only; the session's files go at SessionEnd" {
  space_def acme <<<$'id: acmeroot22\ncoordinator: none'
  wsm install acme >/dev/null
  summary '{"v":1,"total":1,"spaces":{"acmeroot22":{"space":"acme","approvals":1,"unhandled":0,"oldest":"2026-10-24T10:00:00.000Z","items":["merge core +1"]}}}'
  session a
  hook a session-start SessionStart source=startup
  [ "$HRC" -eq 0 ] && [ -z "$HOUT" ]
  hook a "listen --max 60" SessionStart source=startup
  [ "$HRC" -eq 0 ] && [ -z "$HERR" ]
  hook a prompt UserPromptSubmit prompt=x
  [ "$HOUT" = "anfs inbox: 1 waiting here (merge core +1): anfs inbox" ]
  [ ! -e "$L" ]
  [ -e "$XDG_STATE_HOME/anfs/claude/$(sid a).inbox" ]
  hook a session-end SessionEnd reason=other
  [ ! -e "$XDG_STATE_HOME/anfs/claude/$(sid a).inbox" ]
  [ ! -e "$L" ]
  # with no Claude ancestor too (the inbox needs none)
  input "$T/in" z UserPromptSubmit prompt=x
  run "$HOOK" prompt < "$T/in"
  [ "$output" = "anfs inbox: 1 waiting here (merge core +1): anfs inbox" ]
}

# --- outside the spaces ----------------------------------------------------------------------

@test "outside WSM_SPACES_HOME the hook exits 0 before sourcing a library; unset, it asks wsm config get" {
  # a copy of the hook whose libraries only leave a mark
  mkdir -p "$T/lib/claude/anfs" "$T/lib/anfs" "$T/elsewhere" "$R-other"
  cp "$HOOK" "$T/lib/claude/anfs/hook"
  printf 'echo sourced >> "%s"; exit 0\n' "$T/mark" > "$T/lib/anfs/bash.sh"
  input "$T/in" a SessionStart source=startup
  local h="$T/lib/claude/anfs/hook"
  ( cd "$T/elsewhere" && "$h" session-start < "$T/in" )
  # a sibling whose name starts like the root's is not below it; a relative root is nothing
  ( cd "$R-other" && "$h" session-start < "$T/in" )
  ( cd "$SP" && WSM_SPACES_HOME=spaces "$h" session-start < "$T/in" )
  [ ! -e "$T/mark" ]
  # the root itself and below it (~ expanded): on to the libraries
  ( cd "$R" && "$h" session-start < "$T/in" )
  local tilde='~'
  ( cd "$SP" && WSM_SPACES_HOME="$tilde/spaces/" "$h" prompt < "$T/in" )
  [ "$(cat "$T/mark")" = $'sourced\nsourced' ]
  # unset: wsm config get says where (the shipped default, ~/spaces), once per call
  mkdir -p "$WSM_CONFIG_HOME"
  ln -s "$CORE/packages/wsm/home/.config/wsm/wsm.env" "$WSM_CONFIG_HOME/wsm.env"
  rm "$T/mark"
  ( cd "$T/elsewhere" && env -u WSM_SPACES_HOME "$h" session-start < "$T/in" )
  [ ! -e "$T/mark" ]
  ( cd "$SP" && env -u WSM_SPACES_HOME "$h" session-start < "$T/in" )
  [ "$(cat "$T/mark")" = sourced ]
  # the real hook, in a session started without it: the claim as usual
  unset WSM_SPACES_HOME
  session a
  export WSM_SPACES_HOME="$R"
  hook a session-start SessionStart source=startup
  [[ "$HOUT" == "anfs: this session is the coordinator of acme"* ]]
}

@test "no recorded policy: the default, a coordinator" {
  rm -f "$XDG_STATE_HOME/anfs/leases/acmeroot22/coordinator.policy"
  session a
  hook a session-start SessionStart source=startup
  [[ "$HOUT" == "anfs: this session is the coordinator of acme"* ]]
  [ "$(lease_field pid)" = "$(spid a)" ]
}

# --- only at a space's root ------------------------------------------------------------------

@test "a candidate only at the space's root: below it no claim, no takeover, no listen, the holder named; a nested space's root is its own" {
  space_def acme lgat/next <<<$'id: nextspace1'
  wsm install acme/lgat/next >/dev/null
  local L2="$XDG_STATE_HOME/anfs/leases/nextspace1/coordinator.json"
  mkdir -p "$SP/sub/dir" "$SP/lgat/next/core"
  summary '{"v":1,"total":1,"spaces":{"acmeroot22":{"space":"acme","approvals":1,"unhandled":0,"oldest":"2026-10-24T10:00:00.000Z","items":["merge core +1"]}}}'
  session a
  # below acme's root (not a space itself): nobody holds it, and this session will not
  hook a session-start SessionStart source=startup cwd="$SP/sub/dir"
  [ "$HRC" -eq 0 ]
  [[ "$HOUT" == "anfs: acme has no coordinator now (a session started at its root, "*"/spaces/acme, becomes it); this session does not listen." ]] || { echo "$HOUT"; false; }
  hook a "listen --max 60" SessionStart source=startup cwd="$SP/sub/dir"
  [ "$HRC" -eq 0 ] && [ -z "$HERR" ]
  hook a prompt UserPromptSubmit prompt=x cwd="$SP/sub/dir"
  [ "$HOUT" = "anfs inbox: 1 waiting here (merge core +1): anfs inbox" ]
  [ ! -e "$L" ]
  # lgat is a directory of acme, not a space: below acme's root too
  hook a session-start SessionStart source=startup cwd="$SP/lgat"
  [[ "$HOUT" == "anfs: acme has no coordinator now"* ]]
  [ ! -e "$L" ] && [ "$(events_of lease.claimed)" -eq 0 ]
  # at the root (spelled with ..: the physical directories compared): a claim
  session b
  hook b session-start SessionStart source=startup cwd="$SP/sub/.."
  [[ "$HOUT" == "anfs: this session is the coordinator of acme"* ]]
  [ "$(lease_field pid)" = "$(spid b)" ]
  # below the root, the holder named
  hook a session-start SessionStart source=resume cwd="$SP/sub/dir"
  [[ "$HOUT" == "anfs: the coordinator of acme is claude:bbbbbbbb (another session, working, since "*"); this session does not listen." ]]
  # the holder dies: below the root, no takeover
  die b
  hook a prompt UserPromptSubmit prompt=x cwd="$SP/sub/dir"
  [ "$HRC" -eq 0 ]
  [[ "$HOUT" != *"coordinator"* ]]
  [ "$(lease_field pid)" != "$(spid a)" ] && [ "$(events_of lease.claimed)" -eq 1 ]
  # the nested space's root is its own space's: a claim of lgat/next, none of acme
  session c
  hook c session-start SessionStart source=startup cwd="$SP/lgat/next"
  [[ "$HOUT" == "anfs: this session is the coordinator of acme/lgat/next"* ]]
  [ "$(L="$L2" lease_field pid)" = "$(spid c)" ]
  [ "$(lease_field pid)" != "$(spid c)" ]
  # and below it, nothing of lgat/next is claimed by another
  session d
  hook d prompt UserPromptSubmit prompt=x cwd="$SP/lgat/next/core"
  [[ "$HOUT" != *"is now the coordinator"* ]]
  [ "$(L="$L2" lease_field pid)" = "$(spid c)" ]
}

@test "a holder whose cwd moves below the root stays the holder: silent prompts, Stop re-arms, SessionEnd releases" {
  mkdir -p "$SP/sub"
  session a
  hook a session-start SessionStart source=startup
  local claim
  claim=$(lease_field claim)
  hook a prompt UserPromptSubmit prompt=x cwd="$SP/sub"
  [ "$HRC" -eq 0 ] && [ -z "$HOUT" ]
  hook_bg a stop "listen --max 1" Stop cwd="$SP/sub"
  hook_wait a stop
  [ "$HRC" -eq 2 ]
  [[ "$(cat "$T/s-a/stop.err")" == *"still listening"* ]]
  [ "$(lease_field claim)" = "$claim" ]
  hook a session-end SessionEnd reason=other cwd="$SP/sub"
  [ "$(lease_field state)" = free ]
}

# --- the status line -------------------------------------------------------------------------

# statusline <session> [cwd]: the statusLine entry with Claude Code's status line input for
# <session>, run straight from the test (it needs no Claude ancestor); its stdout into SOUT
statusline() {
  printf '{"cwd":"%s","session_id":"%s","model":{"id":"m","display_name":"M"},"workspace":{"current_dir":"%s","project_dir":"%s"},"version":"2.1.309"}\n' \
    "${2:-$SP}" "$(sid "$1")" "${2:-$SP}" "${2:-$SP}" > "$T/sl.in"
  SOUT=$("$HOOK" statusline < "$T/sl.in"); SRC=$?
  [ "$SRC" -eq 0 ]
}

@test "statusline: space and role coordinator in the holding session, role none in the others; nothing outside or in runs; no ps, no wsm" {
  mkdir -p "$SP/sub/dir" "$HOME/elsewhere"
  session a
  session b
  hook a session-start SessionStart source=startup
  hook b session-start SessionStart source=startup
  # ps and wsm leave marks from here on: the status line runs neither
  printf '#!/bin/sh\necho ps >> "%s"\nexit 1\n' "$T/mark" > "$T/bin/ps"
  rm "$HOME/.local/bin/wsm"
  printf '#!/bin/sh\necho wsm >> "%s"\nexit 1\n' "$T/mark" > "$HOME/.local/bin/wsm"
  chmod +x "$T/bin/ps" "$HOME/.local/bin/wsm"
  statusline a
  [ "$SOUT" = "space: acme role: coordinator" ] || { echo "out=$SOUT"; false; }
  statusline a "$SP/sub/dir"
  [ "$SOUT" = "space: acme role: coordinator" ]
  statusline b
  [ "$SOUT" = "space: acme role: none" ]
  statusline z "$SP/sub/dir"
  [ "$SOUT" = "space: acme role: none" ]
  # outside the spaces, in a run, without WSM_SPACES_HOME (no wsm config get), no input
  SOUT=$(cd "$HOME/elsewhere" && "$HOOK" statusline < "$T/sl.in")
  [ -z "$SOUT" ]
  statusline a "$HOME/elsewhere"
  [ -z "$SOUT" ]
  statusline a
  SOUT=$(ANFS_RUN=r1 "$HOOK" statusline < "$T/sl.in")
  [ -z "$SOUT" ]
  SOUT=$(env -u WSM_SPACES_HOME "$HOOK" statusline < "$T/sl.in")
  [ -z "$SOUT" ]
  SOUT=$("$HOOK" statusline < /dev/null)
  [ -z "$SOUT" ]
  [ ! -e "$T/mark" ]
  # expired (a working lease past work_ttl on the fake clock), then released: role none
  echo $(( EPOCHSECONDS + 8000 )) > "$T/clock"
  statusline a
  [ "$SOUT" = "space: acme role: none" ]
  rm "$T/clock"
  statusline a
  [ "$SOUT" = "space: acme role: coordinator" ]
  # a space with no id (no lease possible): role none
  NOID=1 space_def acme noid <<<'coordinator: claude'
  wsm install acme/noid >/dev/null
  statusline a "$SP/noid"
  [ "$SOUT" = "space: acme/noid role: none" ]
  [ ! -e "$T/mark" ]
  rm "$T/bin/ps"
  hook a session-end SessionEnd reason=other
  statusline a
  [ "$SOUT" = "space: acme role: none" ]
  # no event written by the status line: only the claim and the release
  [ "$(events_of lease.claimed)" -eq 1 ] && [ "$(events_of lease.released)" -eq 1 ]
}

@test "statusline: a nested space's path; a dead holder's lease is role none" {
  space_def acme lgat/next <<<$'id: nextspace1'
  wsm install acme/lgat/next >/dev/null
  local sp="$WSM_SPACES_HOME/acme/lgat/next"
  [ -f "$sp/space.yml" ]
  cd "$sp"
  session a
  hook a session-start SessionStart source=startup cwd="$sp"
  [[ "$HOUT" == "anfs: this session is the coordinator of acme/lgat/next"* ]] || { echo "$HOUT"; false; }
  statusline a "$sp"
  [ "$SOUT" = "space: acme/lgat/next role: coordinator" ]
  # in the parent space, the same session holds nothing
  statusline a "$SP"
  [ "$SOUT" = "space: acme role: none" ]
  die a
  statusline a "$sp"
  [ "$SOUT" = "space: acme/lgat/next role: none" ]
}

# --- anfs: enabled|none (agents/06's anfs-key) ---------------------------------------------------

# Every entry of session <n> in the space, and the status line: all silent, nothing claimed, no
# session file
silent_everywhere() {
  local n="$1"
  hook "$n" session-start SessionStart source=startup
  [ "$HRC" -eq 0 ] && [ -z "$HOUT" ] && [ -z "$HERR" ] || { echo "session-start: $HOUT $HERR"; return 1; }
  hook "$n" "listen --max 60" SessionStart source=startup
  [ "$HRC" -eq 0 ] && [ -z "$HOUT" ] && [ -z "$HERR" ] || { echo "listen: $HOUT $HERR"; return 1; }
  hook "$n" "listen --max 60" Stop
  [ "$HRC" -eq 0 ] && [ -z "$HOUT" ] && [ -z "$HERR" ] || { echo "Stop listen: $HOUT $HERR"; return 1; }
  hook "$n" prompt UserPromptSubmit prompt=x
  [ "$HRC" -eq 0 ] && [ -z "$HOUT" ] && [ -z "$HERR" ] || { echo "prompt: $HOUT $HERR"; return 1; }
  statusline "$n"
  [ -z "$SOUT" ] || { echo "statusline: $SOUT"; return 1; }
  hook "$n" session-end SessionEnd reason=other
  [ "$HRC" -eq 0 ] && [ -z "$HOUT" ] && [ -z "$HERR" ] || { echo "session-end: $HOUT $HERR"; return 1; }
  [ ! -e "$L" ] || { echo "a lease: $(cat "$L")"; return 1; }
  [ -z "$(ls -A "$XDG_STATE_HOME/anfs/claude" 2>/dev/null)" ] || { ls "$XDG_STATE_HOME/anfs/claude"; return 1; }
}

# A machine default for agent sessions in the person's anfs.local.env (what anfs config set writes)
machine() { mkdir -p "$ANFS_CONFIG_HOME"; printf 'ANFS_ENABLED=%s\n' "$1" > "$ANFS_CONFIG_HOME/anfs.local.env"; }

@test "anfs: none silences every entry and the status line: no claim, no listen, no brief, no inbox line" {
  space_def acme <<<$'id: acmeroot22\nanfs: none'
  wsm install acme >/dev/null
  summary '{"v":1,"total":1,"spaces":{"acmeroot22":{"space":"acme","approvals":1,"unhandled":0,"oldest":"2026-10-24T10:00:00.000Z","items":["merge core +1"]}}}'
  session a
  silent_everywhere a
  [ "$(events_of lease.claimed)" -eq 0 ]
  # a nested space's own anfs: decides there; the parent's none does not reach it
  space_def acme lgat/next <<<$'id: nextspace1'
  wsm install acme/lgat/next >/dev/null
  local sp="$WSM_SPACES_HOME/acme/lgat/next"
  statusline a "$sp"
  [ "$SOUT" = "space: acme/lgat/next role: none" ]
  statusline a "$SP"
  [ -z "$SOUT" ]
}

@test "no anfs: follows ANFS_ENABLED both ways (anfs.local.env, the environment); a space with no id too" {
  summary '{"v":1,"total":1,"spaces":{"acmeroot22":{"space":"acme","approvals":1,"unhandled":0,"oldest":"2026-10-24T10:00:00.000Z","items":["merge core +1"]}}}'
  [ ! -e "$XDG_STATE_HOME/anfs/leases/acmeroot22/anfs.policy" ]
  machine none
  session a
  silent_everywhere a
  NOID=1 space_def acme noid <<<'repositories: []'
  wsm install acme/noid >/dev/null
  statusline a "$SP/noid"
  [ -z "$SOUT" ]
  machine enabled
  statusline a "$SP/noid"
  [ "$SOUT" = "space: acme/noid role: none" ]
  hook a session-start SessionStart source=startup
  [[ "$HOUT" == "anfs: this session is the coordinator of acme"* ]] || { echo "$HOUT"; false; }
  statusline a
  [ "$SOUT" = "space: acme role: coordinator" ]
  hook a prompt UserPromptSubmit prompt=x
  [ "$HOUT" = "anfs inbox: 1 waiting here (merge core +1): anfs inbox" ]
  # the environment wins over the file
  SOUT=$(ANFS_ENABLED=none "$HOOK" statusline < "$T/sl.in")
  [ -z "$SOUT" ]
  rm "$ANFS_CONFIG_HOME/anfs.local.env"
  SOUT=$("$HOOK" statusline < "$T/sl.in")
  [ "$SOUT" = "space: acme role: coordinator" ]
}

@test "the space's anfs: beats ANFS_ENABLED both ways" {
  summary '{"v":1,"total":1,"spaces":{"acmeroot22":{"space":"acme","approvals":1,"unhandled":0,"oldest":"2026-10-24T10:00:00.000Z","items":["merge core +1"]}}}'
  space_def acme <<<$'id: acmeroot22\nanfs: none'
  wsm install acme >/dev/null
  machine enabled
  session a
  silent_everywhere a
  SOUT=$(ANFS_ENABLED=enabled "$HOOK" statusline < "$T/sl.in")
  [ -z "$SOUT" ]
  space_def acme <<<$'id: acmeroot22\nanfs: enabled'
  wsm install acme >/dev/null
  machine none
  hook a session-start SessionStart source=startup
  [[ "$HOUT" == "anfs: this session is the coordinator of acme"* ]] || { echo "$HOUT"; false; }
  statusline a
  [ "$SOUT" = "space: acme role: coordinator" ]
  SOUT=$(ANFS_ENABLED=none "$HOOK" statusline < "$T/sl.in")
  [ "$SOUT" = "space: acme role: coordinator" ]
}

@test "a bad anfs: is recorded as none: silent" {
  space_def acme <<<$'id: acmeroot22\nanfs: maybe'
  run wsm install acme
  [[ "$output" == *"acme: anfs: is enabled or none: treated as none"* ]] || { echo "$output"; false; }
  session a
  silent_everywhere a
}
