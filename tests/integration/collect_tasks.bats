#!/usr/bin/env bats

setup() {
  load '../test_helper'
  load_script
  setup_tmpdir
}

teardown() {
  teardown_tmpdir
}

# ── collect_tasks ──────────────────────────────────────────

@test "collect_tasks: sorts by priority (high, medium, low)" {
  mkdir -p tasks
  create_task "tasks/001-low.md" "priority: low" "# Low task"
  create_task "tasks/002-high.md" "priority: high" "# High task"
  create_task "tasks/003-medium.md" "priority: medium" "# Medium task"

  collect_tasks "tasks"

  [ "${#SORTED_TASKS[@]}" -eq 3 ]
  [[ "${SORTED_TASKS[0]}" == *"002-high"* ]]
  [[ "${SORTED_TASKS[1]}" == *"003-medium"* ]]
  [[ "${SORTED_TASKS[2]}" == *"001-low"* ]]
}

@test "collect_tasks: default priority is medium" {
  mkdir -p tasks
  create_task "tasks/001.md" "" "# Task without priority"
  create_task "tasks/002.md" "priority: high" "# High task"

  collect_tasks "tasks"

  [ "${#SORTED_TASKS[@]}" -eq 2 ]
  [[ "${SORTED_TASKS[0]}" == *"002"* ]]
  [[ "${SORTED_TASKS[1]}" == *"001"* ]]
}

@test "collect_tasks: sorts alphabetically within same priority" {
  mkdir -p tasks
  create_task "tasks/003.md" "priority: high" "# Third"
  create_task "tasks/001.md" "priority: high" "# First"
  create_task "tasks/002.md" "priority: high" "# Second"

  collect_tasks "tasks"

  [ "${#SORTED_TASKS[@]}" -eq 3 ]
  [[ "${SORTED_TASKS[0]}" == *"001"* ]]
  [[ "${SORTED_TASKS[1]}" == *"002"* ]]
  [[ "${SORTED_TASKS[2]}" == *"003"* ]]
}

@test "collect_tasks: status strategy filters non-open tasks" {
  DONE_STRATEGY="status"
  mkdir -p tasks
  create_task "tasks/001.md" "status: open\npriority: medium" "# Open"
  create_task "tasks/002.md" "status: done\npriority: medium" "# Done"
  create_task "tasks/003.md" "status: open\npriority: medium" "# Open2"

  collect_tasks "tasks"

  [ "${#SORTED_TASKS[@]}" -eq 2 ]
  [[ "${SORTED_TASKS[0]}" == *"001"* ]]
  [[ "${SORTED_TASKS[1]}" == *"003"* ]]
}

@test "collect_tasks: status strategy treats missing status as open" {
  DONE_STRATEGY="status"
  mkdir -p tasks
  create_task "tasks/001.md" "" "# No status field"

  collect_tasks "tasks"

  [ "${#SORTED_TASKS[@]}" -eq 1 ]
}

@test "collect_tasks: nonexistent directory exits 1" {
  run collect_tasks "nonexistent"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not found"* ]]
}

@test "collect_tasks: empty directory (no .md files) exits 1" {
  mkdir -p tasks
  touch tasks/readme.txt

  run collect_tasks "tasks"
  [ "$status" -eq 1 ]
  [[ "$output" == *"No .md files"* ]]
}

# ── list_tasks ─────────────────────────────────────────────

@test "list_tasks: lists tasks with priority and model info" {
  mkdir -p tasks
  create_task "tasks/001.md" "priority: high\nmodel: sonnet" "# First task"
  create_task "tasks/002.md" "priority: low" "# Second task"

  run list_tasks "tasks"
  [ "$status" -eq 0 ]
  [[ "$output" == *"001"* ]]
  [[ "$output" == *"002"* ]]
  [[ "$output" == *"high"* ]]
  [[ "$output" == *"low"* ]]
  [[ "$output" == *"Total: 2"* ]]
}

# ── dry_run ────────────────────────────────────────────────

@test "dry_run: shows execution plan" {
  mkdir -p tasks
  create_task "tasks/001.md" "priority: high\nmodel: sonnet" "# Build feature"
  create_task "tasks/002.md" "priority: medium" "# Fix bug"

  collect_tasks "tasks"
  run dry_run "tasks"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Execution plan"* ]]
  [[ "$output" == *"001"* ]]
  [[ "$output" == *"002"* ]]
}

@test "dry_run: respects --from flag" {
  FROM_TASK="002"
  mkdir -p tasks
  create_task "tasks/001.md" "" "# First"
  create_task "tasks/002.md" "" "# Second"
  create_task "tasks/003.md" "" "# Third"

  collect_tasks "tasks"
  run dry_run "tasks"
  [ "$status" -eq 0 ]
  [[ "$output" != *"1."*"001"* ]]
  [[ "$output" == *"002"* ]]
  [[ "$output" == *"003"* ]]
}
