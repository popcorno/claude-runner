#!/usr/bin/env bats

setup() {
  load '../test_helper'
  setup_tmpdir

  MOCK_BIN="$TEST_TMPDIR/mock_bin"
  mkdir -p "$MOCK_BIN"

  # Mock claude
  create_mock "$MOCK_BIN" "claude" 'echo "mock claude output"'
  # Mock git
  create_mock "$MOCK_BIN" "git" '
case "$1" in
  rev-parse) echo "true" ;;
  diff) exit 0 ;;
  ls-files) echo "" ;;
  add|commit|checkout|clean) exit 0 ;;
  *) exit 0 ;;
esac'

  inject_mock_path "$MOCK_BIN"

  # Initialize a fake git repo so git rev-parse works
  command git init -q "$TEST_TMPDIR" 2>/dev/null || true
}

teardown() {
  teardown_tmpdir
}

@test "cli: --help exits 0 and shows usage" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"USAGE"* ]]
  [[ "$output" == *"OPTIONS"* ]]
  [[ "$output" == *"EXAMPLES"* ]]
}

@test "cli: --version exits 0 and shows version" {
  run bash "$SCRIPT" --version
  [ "$status" -eq 0 ]
  [[ "$output" == *"claude-runner v"* ]]
}

@test "cli: unknown flag exits 1" {
  run bash "$SCRIPT" --bogus-flag
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown option"* ]]
}

@test "cli: --list with tasks shows listing" {
  mkdir -p tasks/open
  create_task "tasks/open/001.md" "priority: high\nmodel: sonnet" "# First task"
  create_task "tasks/open/002.md" "priority: low" "# Second task"

  run bash "$SCRIPT" --list
  [ "$status" -eq 0 ]
  [[ "$output" == *"001"* ]]
  [[ "$output" == *"002"* ]]
  [[ "$output" == *"Total:"* ]]
}

@test "cli: --dry-run with tasks shows plan" {
  mkdir -p tasks/open
  create_task "tasks/open/001.md" "priority: high" "# Task one"
  create_task "tasks/open/002.md" "" "# Task two"

  run bash "$SCRIPT" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Execution plan"* ]]
  [[ "$output" == *"001"* ]]
}

@test "cli: missing tasks directory exits 1" {
  # No tasks/open directory
  run bash "$SCRIPT" --list
  [ "$status" -eq 1 ]
  [[ "$output" == *"not found"* ]]
}

@test "cli: empty tasks directory exits 1" {
  mkdir -p tasks/open
  # No .md files

  run bash "$SCRIPT" --list
  [ "$status" -eq 1 ]
  [[ "$output" == *"No .md files"* ]]
}

# ── Regression tests ───────────────────────────────────────

@test "regression: --list does not fail silently" {
  mkdir -p tasks/open
  create_task "tasks/open/001.md" "" "# A task"

  run bash "$SCRIPT" --list
  [ "$status" -eq 0 ]
  # Should produce meaningful output, not fail silently
  [ -n "$output" ]
  [[ "$output" == *"001"* ]]
}

@test "regression: --dry-run does not fail silently" {
  mkdir -p tasks/open
  create_task "tasks/open/001.md" "" "# A task"

  run bash "$SCRIPT" --dry-run
  [ "$status" -eq 0 ]
  [ -n "$output" ]
  [[ "$output" == *"001"* ]]
}

@test "regression: running with no args and no tasks dir gives useful error" {
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
}

@test "cli: --task with nonexistent file exits 1" {
  run bash "$SCRIPT" --task "nonexistent.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not found"* ]]
}

@test "cli: custom tasks dir via positional argument" {
  mkdir -p my-custom-tasks
  create_task "my-custom-tasks/001.md" "" "# Custom task"

  run bash "$SCRIPT" my-custom-tasks --list
  [ "$status" -eq 0 ]
  [[ "$output" == *"001"* ]]
}

@test "cli: --task resolves short filename against tasks dir" {
  mkdir -p tasks/open
  create_task "tasks/open/041-my-task.md" "" "# My task"

  run bash "$SCRIPT" --task "041-my-task.md"
  # Should find the file (may fail at claude execution, but not at "not found")
  [[ "$output" != *"Task file not found"* ]]
}

@test "cli: --task short filename not found anywhere exits 1" {
  mkdir -p tasks/open

  run bash "$SCRIPT" --task "nonexistent-task.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not found"* ]]
}
