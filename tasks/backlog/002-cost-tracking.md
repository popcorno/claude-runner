---
priority: medium
model: opus
---

# Add cost tracking and reporting

Parse Claude CLI JSON output to track and report per-task costs.

## Details

- Add `--output-format json` to the `claude -p` invocation to get structured output
- Parse the JSON response to extract cost/usage information (tokens used, cost if available)
- Store cost data in new report arrays: `REPORT_COSTS=()` and `REPORT_TOKENS=()`
- Display per-task cost in `print_report()` as an additional column
- Show total cost summary at the bottom of the report
- When `--verbose` is used, also show input/output token counts per task
- The JSON output from `claude -p --output-format json` wraps the result; the actual text output needs to be extracted from the JSON for display (the `result` field)
- Currently the script pipes stdout directly -- this needs to change to capture into a variable, parse, and then display

## Affected files

- `bin/claude-runner.sh`

## Tests

- Add unit tests for the JSON parsing function (mock JSON responses in bats tests)

## Acceptance criteria

- After each run, the report shows cost per task and total
- Works gracefully when cost info is unavailable (e.g., older CLI versions)

## Constraints

- Must not break non-verbose output
- Must handle both JSON and non-JSON output gracefully (fallback if --output-format is not supported)
