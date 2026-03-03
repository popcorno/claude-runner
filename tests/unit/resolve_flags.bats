#!/usr/bin/env bats

setup() {
  load '../test_helper'
  load_script
}

# ── resolve_model_flag ─────────────────────────────────────

@test "resolve_model_flag: opus" {
  run resolve_model_flag "opus"
  [ "$status" -eq 0 ]
  [ "$output" = "--model opus" ]
}

@test "resolve_model_flag: sonnet" {
  run resolve_model_flag "sonnet"
  [ "$status" -eq 0 ]
  [ "$output" = "--model sonnet" ]
}

@test "resolve_model_flag: haiku" {
  run resolve_model_flag "haiku"
  [ "$status" -eq 0 ]
  [ "$output" = "--model haiku" ]
}

@test "resolve_model_flag: opusplan" {
  run resolve_model_flag "opusplan"
  [ "$status" -eq 0 ]
  [ "$output" = "--model opus" ]
}

@test "resolve_model_flag: custom model ID" {
  run resolve_model_flag "claude-3-opus-20240229"
  [ "$status" -eq 0 ]
  [ "$output" = "--model claude-3-opus-20240229" ]
}

# ── resolve_permission_flag ────────────────────────────────

@test "resolve_permission_flag: DANGEROUS_MODE=true returns flag" {
  DANGEROUS_MODE=true
  run resolve_permission_flag
  [ "$status" -eq 0 ]
  [ "$output" = "--dangerously-skip-permissions" ]
}

@test "resolve_permission_flag: DANGEROUS_MODE=false returns empty" {
  DANGEROUS_MODE=false
  run resolve_permission_flag
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}
