#!/usr/bin/env bats

setup() {
  load '../test_helper'
  load_script
  setup_tmpdir
}

teardown() {
  teardown_tmpdir
}

# ── Dependency skipping in main loop ──────────────────────

# We test the dependency resolution logic by simulating the main loop's
# FAILED_TASK_SLUGS tracking and dep checking. Full main() tests would
# require mocking claude CLI, so we test the building blocks here.

@test "dependency resolution: task with failed dep is detected" {
  create_task "open/001-base.md" "priority: high" "# Base task"
  create_task "open/002-depends.md" "priority: medium\ndepends-on: 001" "# Depends on 001"

  # Simulate: 001 has failed
  declare -A FAILED_TASK_SLUGS=(["001-base"]=1)

  local deps
  deps=$(get_task_dependencies "open/002-depends.md")
  [ -n "$deps" ]

  local dep_failed=""
  while IFS= read -r dep; do
    for failed_slug in "${!FAILED_TASK_SLUGS[@]}"; do
      if task_matches_dep "$failed_slug" "$dep"; then
        dep_failed="$dep"
        break 2
      fi
    done
  done <<< "$deps"

  [ "$dep_failed" = "001" ]
}

@test "dependency resolution: task with no failed deps passes" {
  create_task "open/001-base.md" "priority: high" "# Base task"
  create_task "open/002-depends.md" "priority: medium\ndepends-on: 001" "# Depends on 001"

  # Simulate: no failures
  declare -A FAILED_TASK_SLUGS=()

  local deps
  deps=$(get_task_dependencies "open/002-depends.md")

  local dep_failed=""
  while IFS= read -r dep; do
    for failed_slug in "${!FAILED_TASK_SLUGS[@]}"; do
      if task_matches_dep "$failed_slug" "$dep"; then
        dep_failed="$dep"
        break 2
      fi
    done
  done <<< "$deps"

  [ -z "$dep_failed" ]
}

@test "dependency resolution: transitive deps detected" {
  create_task "open/003-transitive.md" "priority: low\ndepends-on: 002" "# Depends on 002"

  # Simulate: both 001 and 002 have failed (002 was skipped due to 001)
  declare -A FAILED_TASK_SLUGS=(["001-base"]=1 ["002-depends"]=1)

  local deps
  deps=$(get_task_dependencies "open/003-transitive.md")

  local dep_failed=""
  while IFS= read -r dep; do
    for failed_slug in "${!FAILED_TASK_SLUGS[@]}"; do
      if task_matches_dep "$failed_slug" "$dep"; then
        dep_failed="$dep"
        break 2
      fi
    done
  done <<< "$deps"

  [ "$dep_failed" = "002" ]
}

@test "dependency resolution: multiple deps, one failed" {
  create_task "open/004-multi.md" "priority: medium\ndepends-on: 001, 003" "# Depends on 001 and 003"

  # Simulate: only 003 failed
  declare -A FAILED_TASK_SLUGS=(["003-feature"]=1)

  local deps
  deps=$(get_task_dependencies "open/004-multi.md")

  local dep_failed=""
  while IFS= read -r dep; do
    for failed_slug in "${!FAILED_TASK_SLUGS[@]}"; do
      if task_matches_dep "$failed_slug" "$dep"; then
        dep_failed="$dep"
        break 2
      fi
    done
  done <<< "$deps"

  [ "$dep_failed" = "003" ]
}

@test "dependency resolution: task without depends-on is unaffected by failures" {
  create_task "open/002-independent.md" "priority: medium" "# No dependencies"

  declare -A FAILED_TASK_SLUGS=(["001-base"]=1)

  local deps
  deps=$(get_task_dependencies "open/002-independent.md")

  [ -z "$deps" ]
}

@test "mark_task_failed called for skipped dependency task (move strategy)" {
  DONE_STRATEGY="move"
  FAILED_DIR="./failed"
  mkdir -p open failed
  create_task "open/002-depends.md" "priority: medium\ndepends-on: 001" "# Depends on 001"

  mark_task_failed "open/002-depends.md"

  [ ! -f "open/002-depends.md" ]
  [ -f "failed/002-depends.md" ]
}
