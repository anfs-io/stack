#!/usr/bin/env bats
# Tests for macOS keychain caching functions
# Run: bats tests/keychain.bats

MACOS_ZSH="macos/.config/zsh/op/macos.zsh"
TEST_ENV="bats-test-env"
TEST_TOKEN="fake-sa-token-for-testing"
TEST_KEYCHAIN_KEY="op-sa-token-${TEST_ENV}"

setup() {
  # Clean up any leftover test entries
  security delete-generic-password -a "$USER" -s "$TEST_KEYCHAIN_KEY" 2>/dev/null || true
}

teardown() {
  security delete-generic-password -a "$USER" -s "$TEST_KEYCHAIN_KEY" 2>/dev/null || true
  unset OP_SA_CREDENTIALS_VAULT
}

# ─────────────────────────────────────────────────────────────────────────────
# _op_sa_token
# ─────────────────────────────────────────────────────────────────────────────

@test "_op_sa_token fails when OP_SA_CREDENTIALS_VAULT is not set" {
  run zsh -c "
    unset OP_SA_CREDENTIALS_VAULT
    source $MACOS_ZSH
    _op_sa_token $TEST_ENV
  "
  [ "$status" -eq 1 ]
  [[ "$output" == *"OP_SA_CREDENTIALS_VAULT is not set"* ]]
}

@test "_op_sa_token returns cached token from keychain" {
  # Pre-populate keychain
  security add-generic-password -a "$USER" -s "$TEST_KEYCHAIN_KEY" -w "$TEST_TOKEN"

  run zsh -c "
    export OP_SA_CREDENTIALS_VAULT=TestVault
    source $MACOS_ZSH
    _op_sa_token $TEST_ENV
  "
  [ "$status" -eq 0 ]
  [ "$output" = "$TEST_TOKEN" ]
}

@test "_op_sa_token fails gracefully when not cached and op read fails" {
  run zsh -c "
    export OP_SA_CREDENTIALS_VAULT=NonExistentVault
    # Mock op to always fail
    op() { return 1; }
    source $MACOS_ZSH
    _op_sa_token $TEST_ENV
  "
  [ "$status" -eq 1 ]
  [[ "$output" == *"Failed to read SA token"* ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# _op_sa_token_clear
# ─────────────────────────────────────────────────────────────────────────────

@test "_op_sa_token_clear fails without env_name" {
  run zsh -c "
    source $MACOS_ZSH
    _op_sa_token_clear
  "
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "_op_sa_token_clear removes token from keychain" {
  # Pre-populate keychain
  security add-generic-password -a "$USER" -s "$TEST_KEYCHAIN_KEY" -w "$TEST_TOKEN"

  # Verify it's there
  run security find-generic-password -a "$USER" -s "$TEST_KEYCHAIN_KEY" -w
  [ "$status" -eq 0 ]

  # Clear it
  run zsh -c "
    source $MACOS_ZSH
    _op_sa_token_clear $TEST_ENV
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"Cleared"* ]]

  # Verify it's gone
  run security find-generic-password -a "$USER" -s "$TEST_KEYCHAIN_KEY" -w
  [ "$status" -ne 0 ]
}

@test "_op_sa_token_clear handles non-existent token gracefully" {
  run zsh -c "
    source $MACOS_ZSH
    _op_sa_token_clear $TEST_ENV
  "
  # Should not fail even if nothing to clear
  [ "$status" -eq 0 ]
}

# ─────────────────────────────────────────────────────────────────────────────
# Round-trip: cache then retrieve
# ─────────────────────────────────────────────────────────────────────────────

@test "round-trip: token cached by _op_sa_token is retrievable" {
  # Manually cache a token
  security add-generic-password -a "$USER" -s "$TEST_KEYCHAIN_KEY" -w "$TEST_TOKEN"

  # Retrieve via function
  run zsh -c "
    export OP_SA_CREDENTIALS_VAULT=TestVault
    source $MACOS_ZSH
    _op_sa_token $TEST_ENV
  "
  [ "$status" -eq 0 ]
  [ "$output" = "$TEST_TOKEN" ]

  # Clear via function
  run zsh -c "
    source $MACOS_ZSH
    _op_sa_token_clear $TEST_ENV
  "
  [ "$status" -eq 0 ]

  # Verify gone
  run security find-generic-password -a "$USER" -s "$TEST_KEYCHAIN_KEY" -w
  [ "$status" -ne 0 ]
}
