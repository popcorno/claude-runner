#!/usr/bin/env bats

setup() {
  load '../test_helper'
  load_script
  setup_tmpdir
}

teardown() {
  teardown_tmpdir
}

@test "load_config: claude-runner.config.json is loaded" {
  cat > claude-runner.config.json <<'JSON'
{
  "tasksDir": "./my-tasks",
  "doneDir": "./my-done",
  "failedDir": "./my-failed",
  "defaultModel": "sonnet",
  "testCommand": "make test",
  "maxRetries": 5,
  "doneStrategy": "status",
  "autoCommit": false,
  "commitPrefix": "fix",
  "stopOnError": false,
  "allowDangerousMode": false,
  "systemPrompt": "Be concise"
}
JSON

  load_config

  [ "$TASKS_DIR" = "./my-tasks" ]
  [ "$DONE_DIR" = "./my-done" ]
  [ "$FAILED_DIR" = "./my-failed" ]
  [ "$DEFAULT_MODEL" = "sonnet" ]
  [ "$TEST_COMMAND" = "make test" ]
  [ "$MAX_RETRIES" = "5" ]
  [ "$DONE_STRATEGY" = "status" ]
  [ "$AUTO_COMMIT" = "false" ]
  [ "$COMMIT_PREFIX" = "fix" ]
  [ "$STOP_ON_ERROR" = "false" ]
  [ "$DANGEROUS_MODE" = "false" ]
  [ "$SYSTEM_PROMPT" = "Be concise" ]
}

@test "load_config: .claude-runner.json fallback" {
  cat > .claude-runner.json <<'JSON'
{
  "defaultModel": "haiku"
}
JSON

  load_config

  [ "$DEFAULT_MODEL" = "haiku" ]
  # Other values remain at defaults
  [ "$TASKS_DIR" = "./tasks/open" ]
}

@test "load_config: claude-runner.config.json takes priority over .claude-runner.json" {
  cat > claude-runner.config.json <<'JSON'
{ "defaultModel": "opus" }
JSON
  cat > .claude-runner.json <<'JSON'
{ "defaultModel": "haiku" }
JSON

  load_config

  [ "$DEFAULT_MODEL" = "opus" ]
}

@test "load_config: no config file uses defaults" {
  load_config

  [ "$TASKS_DIR" = "./tasks/open" ]
  [ "$DEFAULT_MODEL" = "opus" ]
  [ "$MAX_RETRIES" = "2" ]
  [ "$DONE_STRATEGY" = "move" ]
}

@test "load_config: partial config only overrides specified keys" {
  cat > claude-runner.config.json <<'JSON'
{
  "maxRetries": 10
}
JSON

  load_config

  [ "$MAX_RETRIES" = "10" ]
  [ "$DEFAULT_MODEL" = "opus" ]
  [ "$TASKS_DIR" = "./tasks/open" ]
  [ "$DONE_STRATEGY" = "move" ]
}
