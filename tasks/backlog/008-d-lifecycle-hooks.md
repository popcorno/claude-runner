---
priority: high
model: opus
estimated-cost: 3.0000
---

# Add lifecycle hooks to claude-runner

Add a hook system that allows external tools (like Dispatch) to receive notifications about task lifecycle events. Hooks are shell commands configured in `claude-runner.config.json` that receive task data as JSON via stdin.

## Context

For integration with Dispatch (and potentially other monitoring/orchestration tools), claude-runner needs to report task lifecycle events externally. Currently all state changes happen silently inside the script. This task adds configurable shell hooks that fire at key points, enabling external systems to track what the runner is doing.

## Configuration

New config section in `claude-runner.config.json`:

```json
{
  "hooks": {
    "onTaskStart": "dispatch report task-start",
    "onTaskDone": "dispatch report task-done",
    "onTaskFailed": "dispatch report task-failed",
    "onRetry": "dispatch report task-retry"
  }
}
```

All hooks are optional. If not configured, runner behaves exactly as before.

## Hook events and payloads

Each hook command receives a JSON object via stdin with relevant data:

### `onTaskStart`
Fires right before `claude -p` is invoked for a task.

```json
{
  "event": "task_start",
  "task": {
    "file": "001-implement-feature.md",
    "priority": "high",
    "model": "opus",
    "title": "Implement feature X"
  },
  "runner": {
    "tasks_dir": "./tasks/open",
    "total_tasks": 5,
    "current_index": 2
  },
  "timestamp": "2026-03-06T12:00:00Z"
}
```

### `onTaskDone`
Fires after a task completes successfully (tests pass, committed or moved to done).

```json
{
  "event": "task_done",
  "task": {
    "file": "001-implement-feature.md",
    "priority": "high",
    "model": "opus",
    "title": "Implement feature X"
  },
  "result": {
    "attempts": 1,
    "duration_seconds": 120
  },
  "timestamp": "2026-03-06T12:02:00Z"
}
```

### `onTaskFailed`
Fires after a task exhausts all retry attempts and is marked as failed.

```json
{
  "event": "task_failed",
  "task": {
    "file": "001-implement-feature.md",
    "priority": "high",
    "model": "opus",
    "title": "Implement feature X"
  },
  "result": {
    "attempts": 2,
    "duration_seconds": 240,
    "error": "Tests failed after retry"
  },
  "timestamp": "2026-03-06T12:04:00Z"
}
```

### `onRetry`
Fires when a task fails tests and a retry is about to start.

```json
{
  "event": "retry",
  "task": {
    "file": "001-implement-feature.md",
    "priority": "high",
    "model": "opus",
    "title": "Implement feature X"
  },
  "retry": {
    "attempt": 2,
    "max_attempts": 2,
    "test_output_summary": "3 tests failed"
  },
  "timestamp": "2026-03-06T12:02:30Z"
}
```

## Implementation

### 1. Config loading (`load_config`)

- Read `hooks.onTaskStart`, `hooks.onTaskDone`, `hooks.onTaskFailed`, `hooks.onRetry` from config
- Store in variables: `HOOK_ON_TASK_START`, `HOOK_ON_TASK_DONE`, `HOOK_ON_TASK_FAILED`, `HOOK_ON_RETRY`
- Default: empty string (no hook)

### 2. Hook execution function

Add a `fire_hook()` function:

```bash
fire_hook() {
  local hook_cmd="$1"
  local payload="$2"

  if [[ -z "$hook_cmd" ]]; then
    return 0
  fi

  # Fire and forget — hook failure should not affect runner
  echo "$payload" | eval "$hook_cmd" 2>/dev/null &
}
```

Key design decisions:
- **Fire and forget**: hooks run in background (`&`), failures are silently ignored
- Hook failure must NEVER stop or affect the runner's own execution
- Stderr from hooks is suppressed to keep runner output clean

### 3. Integration points in `run_task()`

- Call `fire_hook "$HOOK_ON_TASK_START" "$payload"` right before the `claude -p` invocation
- Call `fire_hook "$HOOK_ON_TASK_DONE" "$payload"` inside the success path (after commit/move to done)
- Call `fire_hook "$HOOK_ON_TASK_FAILED" "$payload"` inside `mark_task_failed` or after all retries exhausted
- Call `fire_hook "$HOOK_ON_RETRY" "$payload"` right before the retry `claude -p` invocation

### 4. Payload construction

Add a helper `build_hook_payload()` that constructs the JSON using `jq`:

```bash
build_hook_payload() {
  local event="$1"
  local task_file="$2"
  # ... additional params

  jq -n \
    --arg event "$event" \
    --arg file "$task_file" \
    # ...
    '{event: $event, task: {file: $file, ...}, timestamp: (now | todate)}'
}
```

## Affected files

- `bin/claude-runner.sh` — `load_config`, new `fire_hook` and `build_hook_payload` functions, integration in `run_task`

## Tests

- `tests/unit/hooks.bats` — test `fire_hook` with mock commands, verify payload structure
- `tests/integration/hooks.bats` — test that hooks fire during task lifecycle (use a hook command that writes to a temp file)
- Test that hook failure does not affect runner execution
- Test that missing hooks (empty config) cause no errors

## Acceptance criteria

- Hooks are configurable via `claude-runner.config.json` under `hooks` key
- All four lifecycle events fire with correct JSON payloads
- Hook failures do not affect runner execution
- Missing/empty hook config causes no errors (backward compatible)
- Payloads include task metadata, timing, and attempt information
- All new functionality has bats tests
- Existing tests continue to pass

## Constraints

- Do not change existing runner behavior when hooks are not configured
- Hooks must not block task execution (fire and forget)
- Keep jq as the only dependency for payload construction (already a dependency)
