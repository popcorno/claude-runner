#!/usr/bin/env bats

setup() {
  load '../test_helper'
  load_script
  setup_tmpdir
}

teardown() {
  teardown_tmpdir
}

# ── get_frontmatter_value ──────────────────────────────────

@test "get_frontmatter_value: existing key" {
  create_task "task.md" "priority: high\nmodel: sonnet" "# Title\n\nBody"
  run get_frontmatter_value "task.md" "priority"
  [ "$status" -eq 0 ]
  [ "$output" = "high" ]
}

@test "get_frontmatter_value: another key" {
  create_task "task.md" "priority: high\nmodel: sonnet" "# Title\n\nBody"
  run get_frontmatter_value "task.md" "model"
  [ "$status" -eq 0 ]
  [ "$output" = "sonnet" ]
}

@test "get_frontmatter_value: missing key returns empty" {
  create_task "task.md" "priority: high" "# Title\n\nBody"
  run get_frontmatter_value "task.md" "model"
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "get_frontmatter_value: no frontmatter returns empty" {
  create_task "task.md" "" "# Just a task\n\nNo frontmatter here."
  run get_frontmatter_value "task.md" "priority"
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "get_frontmatter_value: quoted value (double quotes)" {
  create_task "task.md" 'commit-message: "feat: add thing"' "# Title"
  run get_frontmatter_value "task.md" "commit-message"
  [ "$status" -eq 0 ]
  [ "$output" = "feat: add thing" ]
}

@test "get_frontmatter_value: quoted value (single quotes)" {
  create_task "task.md" "commit-message: 'feat: add thing'" "# Title"
  run get_frontmatter_value "task.md" "commit-message"
  [ "$status" -eq 0 ]
  [ "$output" = "feat: add thing" ]
}

@test "get_frontmatter_value: status field" {
  create_task "task.md" "status: done" "# Title"
  run get_frontmatter_value "task.md" "status"
  [ "$status" -eq 0 ]
  [ "$output" = "done" ]
}

# ── get_task_body ──────────────────────────────────────────

@test "get_task_body: with frontmatter returns body only" {
  create_task "task.md" "priority: high" "# Title\n\nBody text here."
  run get_task_body "task.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"# Title"* ]]
  [[ "$output" == *"Body text here."* ]]
  [[ "$output" != *"priority"* ]]
}

@test "get_task_body: without frontmatter returns entire file" {
  create_task "task.md" "" "# Title\n\nBody text here."
  run get_task_body "task.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"# Title"* ]]
  [[ "$output" == *"Body text here."* ]]
}

# ── get_task_title ─────────────────────────────────────────

@test "get_task_title: standard # Title" {
  create_task "task.md" "priority: high" "# Implement feature X\n\nDetails."
  run get_task_title "task.md"
  [ "$status" -eq 0 ]
  [ "$output" = "Implement feature X" ]
}

@test "get_task_title: no heading returns empty" {
  create_task "task.md" "priority: high" "Just some text without heading."
  run get_task_title "task.md"
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "get_task_title: without frontmatter" {
  create_task "task.md" "" "# My Task Title\n\nBody."
  run get_task_title "task.md"
  [ "$status" -eq 0 ]
  [ "$output" = "My Task Title" ]
}
