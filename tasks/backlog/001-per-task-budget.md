---
priority: high
model: sonnet
---

# Add --max-budget-usd per-task support

Add support for a `budget` frontmatter field that limits the cost of each Claude invocation.

## Details

- Add a new frontmatter field `budget` (numeric, in USD) that maps to `--max-budget-usd` in the Claude CLI call
- Add a config-level field `maxBudgetUsd` as a default budget for all tasks (can be overridden per-task via frontmatter)
- In `run_task()`, if budget is set, add `--max-budget-usd <value>` to the `claude -p` invocation (both initial run and retry fix prompts)
- In `load_config()`, read `maxBudgetUsd` from config using the existing `jq -r '.field | values'` pattern
- Add a new variable `MAX_BUDGET_USD=""` to the defaults section
- In `resolve_model_flag()` or a new `resolve_budget_flag()`, produce the flag string

## Affected files

- `bin/claude-runner.sh`

## Tests

- Add unit tests in `tests/unit/resolve_flags.bats` for the new budget flag resolution
- Add integration test that validates budget field is read from config

## Acceptance criteria

- `budget: 0.50` in frontmatter causes `--max-budget-usd 0.50` in the claude command
- Config-level `maxBudgetUsd` default works
- Per-task frontmatter overrides config default

## Constraints

- Do not change existing flag resolution logic, add alongside it
