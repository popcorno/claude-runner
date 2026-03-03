#!/usr/bin/env bats

setup() {
  load '../test_helper'
  load_script
  setup_tmpdir
}

teardown() {
  teardown_tmpdir
}

# ── parse_claude_output ──────────────────────────────────────

@test "parse_claude_output: extracts result from valid JSON" {
  parse_claude_output '{"result": "hello world", "cost_usd": 0.42}'
  [ "$PARSED_RESULT" = "hello world" ]
}

@test "parse_claude_output: extracts cost from valid JSON" {
  parse_claude_output '{"result": "done", "cost_usd": 0.42}'
  [ "$PARSED_COST_USD" = "0.42" ]
}

@test "parse_claude_output: handles absent cost_usd" {
  parse_claude_output '{"result": "done"}'
  [ "$PARSED_RESULT" = "done" ]
  [ "$PARSED_COST_USD" = "" ]
}

@test "parse_claude_output: handles null cost_usd" {
  parse_claude_output '{"result": "done", "cost_usd": null}'
  [ "$PARSED_RESULT" = "done" ]
  [ "$PARSED_COST_USD" = "" ]
}

@test "parse_claude_output: handles zero cost" {
  parse_claude_output '{"result": "done", "cost_usd": 0}'
  [ "$PARSED_COST_USD" = "0" ]
}

@test "parse_claude_output: falls back on non-JSON input" {
  parse_claude_output 'plain text output from claude'
  [ "$PARSED_RESULT" = "plain text output from claude" ]
  [ "$PARSED_COST_USD" = "" ]
}

@test "parse_claude_output: falls back on invalid JSON" {
  parse_claude_output '{not valid json'
  [ "$PARSED_RESULT" = "{not valid json" ]
  [ "$PARSED_COST_USD" = "" ]
}

@test "parse_claude_output: clears previous values on second call" {
  parse_claude_output '{"result": "first", "cost_usd": 1.0}'
  parse_claude_output '{"result": "second"}'
  [ "$PARSED_RESULT" = "second" ]
  [ "$PARSED_COST_USD" = "" ]
}

@test "parse_claude_output: handles empty result field" {
  parse_claude_output '{"result": "", "cost_usd": 0.01}'
  [ "$PARSED_RESULT" = "" ]
  [ "$PARSED_COST_USD" = "0.01" ]
}

@test "parse_claude_output: handles multiline result" {
  local json
  json=$(printf '{"result": "line one\\nline two", "cost_usd": 0.1}')
  parse_claude_output "$json"
  [[ "$PARSED_RESULT" == *"line one"* ]]
  [[ "$PARSED_RESULT" == *"line two"* ]]
  [ "$PARSED_COST_USD" = "0.1" ]
}
