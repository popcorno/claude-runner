---
priority: high
model: sonnet
---

# Add rate limit detection and graceful retry

Detect rate limit errors from the Claude CLI and implement exponential backoff retry.

## Details

- When `claude -p` exits with a non-zero code, capture stderr and check for rate limit indicators (HTTP 429, "rate limit", "too many requests", "overloaded")
- Implement a retry loop with exponential backoff: wait 30s, 60s, 120s before giving up
- Display a countdown timer during the wait so the user knows the runner is alive
- Add a config field `rateLimitRetries` (default: 3) for the number of rate limit retry attempts
- The rate limit retry is separate from the test failure retry (`maxRetries`); rate limit retries happen at the Claude invocation level, test retries happen at the test level
- Capture stderr separately from stdout in the `claude -p` call

## Affected files

- `bin/claude-runner.sh`

## Tests

- Add a helper function `detect_rate_limit()` that takes stderr text and returns 0 (rate limited) or 1 (other error)
- Add unit tests for `detect_rate_limit()` with various error message formats

## Acceptance criteria

- Rate-limited invocations are retried with backoff
- Non-rate-limit errors fail immediately as before
- Countdown timer is visible in non-verbose mode

## Constraints

- Do not change behavior for non-rate-limit errors
- Keep the retry logic cleanly separated from test retry logic
