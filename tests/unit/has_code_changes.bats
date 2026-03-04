#!/usr/bin/env bats

setup() {
  load '../test_helper'
  load_script
  setup_tmpdir

  # Initialize a git repo for each test
  git init -q .
  git add -A
  git commit -q -m "initial" --allow-empty
}

teardown() {
  teardown_tmpdir
}

# ── has_code_changes ──────────────────────────────────────────

@test "has_code_changes: modified file returns 0" {
  echo "hello" > code.txt
  git add code.txt && git commit -q -m "add code"
  echo "changed" > code.txt
  run has_code_changes "tasks/open/task.md"
  [ "$status" -eq 0 ]
}

@test "has_code_changes: clean repo returns 1" {
  run has_code_changes "tasks/open/task.md"
  [ "$status" -eq 1 ]
}

@test "has_code_changes: only task file changed returns 1" {
  mkdir -p tasks/open
  echo "task content" > tasks/open/task.md
  run has_code_changes "tasks/open/task.md"
  [ "$status" -eq 1 ]
}

@test "has_code_changes: task file + code changed returns 0" {
  echo "hello" > code.txt
  git add code.txt && git commit -q -m "add code"
  echo "changed" > code.txt
  mkdir -p tasks/open
  echo "task content" > tasks/open/task.md
  run has_code_changes "tasks/open/task.md"
  [ "$status" -eq 0 ]
}

@test "has_code_changes: new untracked file returns 0" {
  echo "new file" > newfile.txt
  run has_code_changes "tasks/open/task.md"
  [ "$status" -eq 0 ]
}
