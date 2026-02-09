#!/usr/bin/env bats
# Tests for shared op.zsh functions (_op_env, tool wrappers)
# Run: bats tests/shared.bats

SHARED_ZSH="home/.config/zsh/op.zsh"

teardown() {
  unset OP_SERVICE_ACCOUNT_TOKEN OP_VAULT GH_TOKEN AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
}

# ─────────────────────────────────────────────────────────────────────────────
# _op_env
# ─────────────────────────────────────────────────────────────────────────────

@test "_op_env does nothing when OP_SERVICE_ACCOUNT_TOKEN is not set" {
  run zsh -c "
    unset OP_SERVICE_ACCOUNT_TOKEN
    source $SHARED_ZSH
    _op_env GH_TOKEN 'GitHub CLI Token/credential'
    echo \${GH_TOKEN:-empty}
  "
  [ "$status" -eq 0 ]
  [ "$output" = "empty" ]
}

@test "_op_env does nothing when var is already set" {
  run zsh -c "
    export OP_SERVICE_ACCOUNT_TOKEN=fake
    export OP_VAULT=test
    export GH_TOKEN=already-set
    source $SHARED_ZSH
    _op_env GH_TOKEN 'GitHub CLI Token/credential'
    echo \$GH_TOKEN
  "
  [ "$status" -eq 0 ]
  [ "$output" = "already-set" ]
}

@test "_op_env warns when op read fails" {
  run zsh -c "
    export OP_SERVICE_ACCOUNT_TOKEN=fake
    export OP_VAULT=nonexistent
    source $SHARED_ZSH
    _op_env GH_TOKEN 'BadItem/credential' 2>&1
  "
  [[ "$output" == *"Warning: Failed to read"* ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# Tool wrappers
# ─────────────────────────────────────────────────────────────────────────────

@test "gh wrapper is defined when OP_SERVICE_ACCOUNT_TOKEN is set" {
  run zsh -c "
    export OP_SERVICE_ACCOUNT_TOKEN=fake
    source $SHARED_ZSH
    whence -w gh
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"function"* ]]
}

@test "gh wrapper is not defined when OP_SERVICE_ACCOUNT_TOKEN is unset" {
  run zsh -c "
    unset OP_SERVICE_ACCOUNT_TOKEN
    source $SHARED_ZSH
    whence -w gh 2>&1 || echo 'not found'
  "
  [[ "$output" != *"function"* ]]
}

@test "aws wrapper is defined when OP_SERVICE_ACCOUNT_TOKEN is set" {
  run zsh -c "
    export OP_SERVICE_ACCOUNT_TOKEN=fake
    source $SHARED_ZSH
    whence -w aws
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"function"* ]]
}

@test "aws wrapper is not defined when OP_SERVICE_ACCOUNT_TOKEN is unset" {
  run zsh -c "
    unset OP_SERVICE_ACCOUNT_TOKEN
    source $SHARED_ZSH
    whence -w aws 2>&1 || echo 'not found'
  "
  [[ "$output" != *"function"* ]]
}
