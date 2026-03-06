---
priority: medium
model: sonnet
estimated-cost: 2.0000
---

# Add --output-format json for machine-readable output

Add a `--output-format` flag that switches runner output from human-readable logs to structured JSON. This allows Dispatch agent and other tools to reliably parse runner results.

## Context

Currently claude-runner outputs colored, human-readable logs to stdout. For integration with Dispatch, the agent needs to parse results programmatically: which tasks ran, their status, duration, number of attempts, etc. A JSON output mode solves this without breaking existing human-readable output.

## Usage

```bash
# JSON output for all tasks
claude-runner --output-format json

# JSON output for a single task (combined with d-002)
claude-runner --run-single task.md --output-format json

# Default (unchanged)
claude-runner                        # human-readable output
claude-runner --output-format text   # explicit human-readable
```

## Output format

### Per-task JSON (streamed, one JSON object per line — JSONL)

Each task emits a single JSON line when it completes:

```json
{"event":"task_done","file":"001-feature.md","title":"Implement feature","status":"done","attempts":1,"duration_seconds":95,"model":"opus","priority":"high"}
```

```json
{"event":"task_failed","file":"002-bugfix.md","title":"Fix bug","status":"failed","attempts":2,"duration_seconds":210,"model":"sonnet","priority":"medium","error":"Tests failed after retry"}
```

### Summary JSON (at the end of the run)

```json
{"event":"run_complete","total":5,"done":3,"failed":1,"skipped":1,"duration_seconds":600}
```

### Design decisions

- **JSONL format** (one object per line) — allows streaming, easy to parse line by line
- **Suppresses all other stdout output** — when `--output-format json` is active, all human-readable logs go to stderr instead
- **Progress/status messages** still go to stderr so the user can see them in terminal while JSON goes to stdout for piping

## Implementation

### 1. Argument parsing (`parse_args`)

- Add `--output-format` flag accepting `text` (default) or `json`
- Store in variable `OUTPUT_FORMAT="text"`

### 2. Output routing

- Add a helper `log_msg()` that checks `OUTPUT_FORMAT`:
  - `text`: prints to stdout as before
  - `json`: prints to stderr (so human messages don't pollute JSON stream)
- Replace direct `echo`/`printf` calls in the main flow with `log_msg`
- The existing `format_time`, color output, and summary report continue to work in `text` mode

### 3. JSON emission

- Add `emit_json()` function that outputs a JSON line to stdout:

```bash
emit_json() {
  local event="$1"
  shift
  # Build JSON with jq from named args
  jq -n -c --arg event "$event" "$@" '{event: $event, ...}'
}
```

- Call `emit_json` at key points:
  - After each task completes (done or failed)
  - After the full run completes (summary)

### 4. Integration points

- In `run_task()`: after success/failure, call `emit_json` with task details
- In `main()`: after the loop, call `emit_json` with run summary
- Only emit when `OUTPUT_FORMAT == "json"`

## Affected files

- `bin/claude-runner.sh` — `parse_args`, output functions, `run_task`, `main`

## Tests

- `tests/e2e/output-format.bats`:
  - Test that `--output-format json` produces valid JSONL on stdout
  - Test that each line is valid JSON (pipe through `jq .`)
  - Test that human-readable messages go to stderr in json mode
  - Test that `--output-format text` (and default) works as before
  - Test that summary line contains correct totals
  - Test per-task lines contain expected fields (file, status, attempts, duration)

## Acceptance criteria

- `--output-format json` produces JSONL on stdout
- Each completed task emits one JSON line with status, timing, and metadata
- A summary JSON line is emitted at the end of the run
- Human-readable output goes to stderr in json mode (not lost, just redirected)
- Default behavior (`text` mode) is completely unchanged
- JSON output is valid and parseable by `jq`
- All new functionality has bats tests
- Existing tests continue to pass

## Constraints

- Do not change default output behavior
- Do not add new dependencies beyond jq
- Keep JSON schema simple and flat (avoid deep nesting)
