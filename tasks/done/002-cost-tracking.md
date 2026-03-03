---
priority: high
model: sonnet
---

# Add cost tracking and reporting

Parse Claude CLI JSON output to track and report per-task costs.

## Details

### Capturing JSON output

- Add `--output-format json` to all `claude -p` invocations (main run + retry fix prompts)
- Capture full output into a variable instead of piping directly to stdout
- Extract the text result from JSON (the `result` field) and display it as before:
  - verbose mode: show full result text
  - quiet mode: show last 20 lines of result text
- If JSON parsing fails (old CLI, unexpected output), fall back to showing raw output

### Parsing cost data

- Add a helper function `parse_claude_output()` that takes JSON output and extracts:
  - `result` — text to display
  - `cost_usd` — cost in USD (may be absent)
- Use `jq` for parsing with graceful fallback
- For retry runs, accumulate cost across attempts (sum all invocations for one task)

### Saving cost to task frontmatter

- When a task completes (done or failed), write `cost: <value>` into the task file's frontmatter via `set_frontmatter_status()` or alongside it
- This way every completed/failed task file has its actual cost recorded
- Field name `cost` (actual spend) — distinct from `budget` (limit) which will be added later

### Reporting

- Add `REPORT_COSTS=()` array alongside existing report arrays
- In `record_result()`, accept cost as a new parameter
- In `print_report()`, show cost per task and total cost at the bottom
- Format: `$0.42` or `-` if unavailable

## Affected files

- `bin/claude-runner.sh`

## Tests

- Add unit tests for `parse_claude_output()` with mock JSON responses
- Test fallback when output is not valid JSON
- Test cost accumulation across retries

## Acceptance criteria

- After each run, the report shows cost per task and total
- Works gracefully when cost info is unavailable (shows `-` instead)
- Verbose and quiet modes both work correctly with JSON capture
- Retry costs are summed per task
- Completed and failed task files have `cost` field in frontmatter

## Constraints

- Must not break existing verbose/quiet output behavior
- Must handle non-JSON output gracefully (fallback)
- Do not change existing `record_result()` callers' argument order — add cost as a new last parameter with default
