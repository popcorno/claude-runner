#!/usr/bin/env bats

setup() {
  load '../test_helper'
  load_script
  setup_tmpdir
}

teardown() {
  teardown_tmpdir
}

# ── get_task_dependencies ─────────────────────────────────

@test "get_task_dependencies: single dependency" {
  create_task "task.md" "depends-on: 001" "# Title"
  run get_task_dependencies "task.md"
  [ "$status" -eq 0 ]
  [ "$output" = "001" ]
}

@test "get_task_dependencies: multiple dependencies" {
  create_task "task.md" "depends-on: 001, 003" "# Title"
  run get_task_dependencies "task.md"
  [ "$status" -eq 0 ]
  local -a lines
  mapfile -t lines <<< "$output"
  [ "${#lines[@]}" -eq 2 ]
  [ "${lines[0]}" = "001" ]
  [ "${lines[1]}" = "003" ]
}

@test "get_task_dependencies: no depends-on returns empty" {
  create_task "task.md" "priority: high" "# Title"
  run get_task_dependencies "task.md"
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "get_task_dependencies: trims whitespace" {
  create_task "task.md" "depends-on:  001 ,  003-some-slug " "# Title"
  run get_task_dependencies "task.md"
  [ "$status" -eq 0 ]
  local -a lines
  mapfile -t lines <<< "$output"
  [ "${lines[0]}" = "001" ]
  [ "${lines[1]}" = "003-some-slug" ]
}

@test "get_task_dependencies: full slug format" {
  create_task "task.md" "depends-on: 001-implement-feature" "# Title"
  run get_task_dependencies "task.md"
  [ "$status" -eq 0 ]
  [ "$output" = "001-implement-feature" ]
}

# ── task_matches_dep ──────────────────────────────────────

@test "task_matches_dep: exact match" {
  run task_matches_dep "001" "001"
  [ "$status" -eq 0 ]
}

@test "task_matches_dep: prefix match with slug" {
  run task_matches_dep "001-implement-feature" "001"
  [ "$status" -eq 0 ]
}

@test "task_matches_dep: full slug match" {
  run task_matches_dep "001-implement-feature" "001-implement-feature"
  [ "$status" -eq 0 ]
}

@test "task_matches_dep: no match" {
  run task_matches_dep "002-other-task" "001"
  [ "$status" -eq 1 ]
}

@test "task_matches_dep: partial number no match" {
  run task_matches_dep "0011-task" "001"
  [ "$status" -eq 1 ]
}
