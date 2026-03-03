#!/usr/bin/env bats

setup() {
  load '../test_helper'
  load_script
  setup_tmpdir
}

teardown() {
  teardown_tmpdir
}

# ── move_task ──────────────────────────────────────────────

@test "move_task: moves file to target directory" {
  mkdir -p src
  echo "content" > src/task.md

  move_task "src/task.md" "dest"

  [ ! -f "src/task.md" ]
  [ -f "dest/task.md" ]
  [ "$(cat dest/task.md)" = "content" ]
}

@test "move_task: creates target directory if missing" {
  echo "content" > task.md

  move_task "task.md" "new/nested/dir"

  [ -d "new/nested/dir" ]
  [ -f "new/nested/dir/task.md" ]
}

@test "move_task: handles already-moved file gracefully" {
  mkdir -p dest
  echo "content" > dest/task.md

  # File doesn't exist at source, but exists at dest — no error
  run move_task "src/task.md" "dest"
  [ "$status" -eq 0 ]
}

@test "move_task: warns when file not found anywhere" {
  run move_task "nonexistent.md" "dest"
  [ "$status" -eq 0 ]
  [[ "$output" == *"not found"* ]]
}

# ── mark_task_done: move strategy ─────────────────────────

@test "mark_task_done: move strategy moves to DONE_DIR" {
  DONE_STRATEGY="move"
  DONE_DIR="./done"
  mkdir -p tasks
  echo "content" > tasks/001.md

  mark_task_done "tasks/001.md"

  [ ! -f "tasks/001.md" ]
  [ -f "done/001.md" ]
}

# ── mark_task_done: status strategy ───────────────────────

@test "mark_task_done: status strategy updates frontmatter" {
  DONE_STRATEGY="status"
  create_task "task.md" "status: open\npriority: high" "# Title"

  mark_task_done "task.md"

  run grep "^status: done" "task.md"
  [ "$status" -eq 0 ]
  # File should still exist in place
  [ -f "task.md" ]
}

# ── mark_task_failed: move strategy ──────────────────────

@test "mark_task_failed: move strategy moves to FAILED_DIR" {
  DONE_STRATEGY="move"
  FAILED_DIR="./failed"
  mkdir -p tasks
  echo "content" > tasks/001.md

  mark_task_failed "tasks/001.md"

  [ ! -f "tasks/001.md" ]
  [ -f "failed/001.md" ]
}

# ── mark_task_failed: status strategy ────────────────────

@test "mark_task_failed: status strategy does not change file" {
  DONE_STRATEGY="status"
  create_task "task.md" "status: open" "# Title"

  local before
  before=$(cat "task.md")

  mark_task_failed "task.md"

  local after
  after=$(cat "task.md")

  [ "$before" = "$after" ]
}
