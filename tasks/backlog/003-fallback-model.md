---
priority: low
model: sonnet
---

# Add fallback model support

Add a `fallbackModel` config field that specifies which model to retry with when the primary model fails.

## Details

- Add a new config field `fallbackModel` (string, e.g., `"sonnet"`) read in `load_config()`
- Add a new frontmatter field `fallback-model` for per-task override
- In `run_task()`, when Claude exits with a non-zero code, instead of immediately marking the task as failed, check if a fallback model is configured
- If fallback model exists and differs from the current model, retry the task with the fallback model before giving up
- The fallback retry should be a single attempt (not subject to maxRetries, which is for test failures)
- Log clearly when falling back: "Primary model (opus) failed, retrying with fallback (sonnet)..."
- Track in report whether fallback was used (add to the notes column)

## Affected files

- `bin/claude-runner.sh`

## Tests

- Add unit tests for fallback model resolution
- Add integration tests for the fallback flow (using mock claude command)

## Acceptance criteria

- When opus fails, sonnet is tried automatically
- If no fallback configured, behavior is unchanged from current

## Constraints

- Do not change the existing retry loop for test failures
- Fallback is for Claude CLI errors only, not test failures
