#!/usr/bin/env bats

setup() {
  load '../test_helper'
  load_script
}

@test "parse_args: --dry-run sets DRY_RUN" {
  parse_args --dry-run
  [ "$DRY_RUN" = "true" ]
}

@test "parse_args: --verbose sets VERBOSE" {
  parse_args --verbose
  [ "$VERBOSE" = "true" ]
}

@test "parse_args: --list sets LIST_ONLY" {
  parse_args --list
  [ "$LIST_ONLY" = "true" ]
}

@test "parse_args: --task sets SINGLE_TASK" {
  parse_args --task "./path/to/file.md"
  [ "$SINGLE_TASK" = "./path/to/file.md" ]
}

@test "parse_args: --from sets FROM_TASK" {
  parse_args --from "003"
  [ "$FROM_TASK" = "003" ]
}

@test "parse_args: positional argument sets CLI_TASKS_DIR and TASKS_DIR" {
  parse_args "./my-tasks"
  [ "$CLI_TASKS_DIR" = "./my-tasks" ]
  [ "$TASKS_DIR" = "./my-tasks" ]
}

@test "parse_args: combined flags" {
  parse_args --verbose --dry-run --from "005"
  [ "$VERBOSE" = "true" ]
  [ "$DRY_RUN" = "true" ]
  [ "$FROM_TASK" = "005" ]
}

@test "parse_args: --version exits 0" {
  run parse_args --version
  [ "$status" -eq 0 ]
  [[ "$output" == *"claude-runner v"* ]]
}

@test "parse_args: --help exits 0" {
  run parse_args --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"USAGE"* ]]
}

@test "parse_args: unknown flag exits 1" {
  run parse_args --bogus
  [ "$status" -eq 1 ]
}

@test "parse_args: --task without value exits 1" {
  run parse_args --task
  [ "$status" -eq 1 ]
}

@test "parse_args: --from without value exits 1" {
  run parse_args --from
  [ "$status" -eq 1 ]
}

# ── Regression: set -e + parse_args with no args ───────────

@test "regression: parse_args with no arguments does not crash under set -e" {
  # The while [[ $# -gt 0 ]] loop should simply not execute
  # This is a regression test for the set -e + && chain bug
  set -e
  parse_args
  # If we reach here, the test passes
  [ "$DRY_RUN" = "false" ]
  [ "$VERBOSE" = "false" ]
  [ "$LIST_ONLY" = "false" ]
}
