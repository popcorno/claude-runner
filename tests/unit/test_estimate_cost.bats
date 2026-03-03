#!/usr/bin/env bats

setup() {
  load '../test_helper'
  setup_tmpdir
  ESTIMATE_SCRIPT="$PROJECT_ROOT/bin/estimate-cost.sh"
  mkdir -p done
}

teardown() {
  teardown_tmpdir
}

# ── Default estimates ───────────────────────────────────────

@test "returns default estimate for sonnet when done dir is empty" {
  run "$ESTIMATE_SCRIPT" --model sonnet --done-dir ./done
  [ "$status" -eq 0 ]
  [ "$output" = "0.5000" ]
}

@test "returns default estimate for haiku" {
  run "$ESTIMATE_SCRIPT" --model haiku --done-dir ./done
  [ "$status" -eq 0 ]
  [ "$output" = "0.0500" ]
}

@test "returns default estimate for opus" {
  run "$ESTIMATE_SCRIPT" --model opus --done-dir ./done
  [ "$status" -eq 0 ]
  [ "$output" = "3.0000" ]
}

@test "returns default estimate for opusplan" {
  run "$ESTIMATE_SCRIPT" --model opusplan --done-dir ./done
  [ "$status" -eq 0 ]
  [ "$output" = "4.0000" ]
}

@test "returns 1.0000 for unknown model" {
  run "$ESTIMATE_SCRIPT" --model claude-custom-99 --done-dir ./done
  [ "$status" -eq 0 ]
  [ "$output" = "1.0000" ]
}

# ── Missing cost field ──────────────────────────────────────

@test "returns default estimate when done tasks have no cost field" {
  create_task "done/001-task.md" "model: sonnet\npriority: medium" "# Task\n\nDone."
  create_task "done/002-task.md" "model: sonnet\npriority: high" "# Task 2\n\nDone."
  run "$ESTIMATE_SCRIPT" --model sonnet --done-dir ./done
  [ "$status" -eq 0 ]
  [ "$output" = "0.5000" ]
}

# ── Historical data ─────────────────────────────────────────

@test "computes average from multiple done tasks for matching model" {
  create_task "done/001-task.md" "model: sonnet\ncost: 0.4000" "# Task 1"
  create_task "done/002-task.md" "model: sonnet\ncost: 0.6000" "# Task 2"
  run "$ESTIMATE_SCRIPT" --model sonnet --done-dir ./done
  [ "$status" -eq 0 ]
  [ "$output" = "0.5000" ]
}

@test "computes average correctly with non-equal costs" {
  create_task "done/001-task.md" "model: opus\ncost: 2.0000" "# Task 1"
  create_task "done/002-task.md" "model: opus\ncost: 4.0000" "# Task 2"
  create_task "done/003-task.md" "model: opus\ncost: 3.0000" "# Task 3"
  run "$ESTIMATE_SCRIPT" --model opus --done-dir ./done
  [ "$status" -eq 0 ]
  [ "$output" = "3.0000" ]
}

# ── Model filtering ─────────────────────────────────────────

@test "ignores tasks with different model" {
  create_task "done/001-task.md" "model: opus\ncost: 5.0000" "# Opus task"
  create_task "done/002-task.md" "model: opus\ncost: 6.0000" "# Another opus task"
  run "$ESTIMATE_SCRIPT" --model sonnet --done-dir ./done
  [ "$status" -eq 0 ]
  [ "$output" = "0.5000" ]
}

@test "uses only matching model tasks when mixed models present" {
  create_task "done/001-task.md" "model: haiku\ncost: 0.1000" "# Haiku task"
  create_task "done/002-task.md" "model: sonnet\ncost: 0.8000" "# Sonnet task"
  create_task "done/003-task.md" "model: opus\ncost: 5.0000" "# Opus task"
  run "$ESTIMATE_SCRIPT" --model sonnet --done-dir ./done
  [ "$status" -eq 0 ]
  [ "$output" = "0.8000" ]
}

# ── Mixed tasks ─────────────────────────────────────────────

@test "handles mix of tasks with and without cost field" {
  create_task "done/001-task.md" "model: sonnet\ncost: 0.4000" "# Task with cost"
  create_task "done/002-task.md" "model: sonnet" "# Task without cost"
  create_task "done/003-task.md" "model: sonnet\ncost: 0.8000" "# Task with cost 2"
  run "$ESTIMATE_SCRIPT" --model sonnet --done-dir ./done
  [ "$status" -eq 0 ]
  [ "$output" = "0.6000" ]
}

# ── Error handling ──────────────────────────────────────────

@test "exits 1 when --model is not provided" {
  run "$ESTIMATE_SCRIPT" --done-dir ./done
  [ "$status" -eq 1 ]
}

@test "exits 1 when --model argument is missing" {
  run "$ESTIMATE_SCRIPT"
  [ "$status" -eq 1 ]
}
