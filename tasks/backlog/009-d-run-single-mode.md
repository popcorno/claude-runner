---
priority: high
model: sonnet
estimated-cost: 1.5000
---

# Add --run-single flag for executing a single task file

Add a `--run-single <file>` CLI flag that allows running exactly one task file without scanning the tasks directory. This enables external orchestrators (like Dispatch) to feed individual tasks to the runner.

## Context

Currently claude-runner always scans `tasksDir` and runs all collected tasks sequentially. For integration with Dispatch, the agent needs to run a specific task file that was downloaded from the database and saved locally. The `--run-single` flag provides this capability.

## Usage

```bash
# Run a single task file
claude-runner --run-single /tmp/dispatch-task-42.md

# Combine with other flags
claude-runner --run-single task.md --dry-run
claude-runner --run-single task.md --verbose
```

## Implementation

### 1. Argument parsing (`parse_args`)

- Add `--run-single` flag that accepts a file path as its argument
- Store in variable `RUN_SINGLE_FILE=""`
- Validate that the file exists and is readable
- `--run-single` is mutually exclusive with `--list`, `--list-backlog`, `--promote`

### 2. Main flow adjustment (`main`)

When `RUN_SINGLE_FILE` is set:
- Skip `collect_tasks()` entirely
- Skip config-based `tasksDir` resolution (config is still loaded for other settings like `testCommand`, `model`, hooks, etc.)
- Call `run_task "$RUN_SINGLE_FILE"` directly
- Exit with the task's exit code (0 for success, 1 for failure)

### 3. Done/failed handling

When running in single mode:
- `doneStrategy` still applies (move or status) — this is important so the caller can check the result
- If `doneStrategy: "move"`, the task file is moved to `doneDir`/`failedDir` as usual
- If `doneStrategy: "status"`, the frontmatter status is updated in place
- The caller (Dispatch agent) can check the exit code and/or the file's final location/status

### 4. Exit code

- Exit `0` if the task completed successfully
- Exit `1` if the task failed (after retries)
- This allows Dispatch agent to simply check `$?`

## Affected files

- `bin/claude-runner.sh` — `parse_args`, `main`

## Tests

- `tests/e2e/run-single.bats`:
  - Test that `--run-single` with a valid task file runs only that task
  - Test that `--run-single` with a non-existent file exits with error
  - Test that `--run-single` combined with `--dry-run` works
  - Test that `--run-single` is mutually exclusive with `--list`
  - Test exit codes (0 for success, 1 for failure)

## Acceptance criteria

- `--run-single <file>` runs exactly one task and exits
- Config is still loaded (testCommand, model, hooks, etc. still apply)
- Exit code reflects task success/failure
- Works with `--dry-run` and `--verbose`
- Mutually exclusive with list/promote flags
- Error message if file doesn't exist
- Existing tests continue to pass

## Constraints

- Do not change the behavior of the default (multi-task) mode
- Config loading must still happen (only task collection is skipped)
- Keep the implementation minimal — reuse `run_task()` as-is
