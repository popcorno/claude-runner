---
priority: medium
model: sonnet
---

# Add --fallback-model support for automatic model fallback on rate limits

When the primary model hits rate limits or is overloaded, Claude CLI can automatically fall back to a secondary model via the `--fallback-model` flag. Add support for this in claude-runner at both config and per-task levels.

## Details

### Config level

Add a new optional field `fallbackModel` to `claude-runner.config.json`:

```json
{
  "fallbackModel": "sonnet"
}
```

In `load_config()`, read this field the same way other config fields are read:

```bash
FALLBACK_MODEL=$(echo "$config" | jq -r '.fallbackModel | values')
```

### Per-task frontmatter

Support a `fallback-model` field in task frontmatter:

```yaml
---
priority: high
model: opus
fallback-model: sonnet
---
```

Per-task `fallback-model` overrides the global `fallbackModel` config.

### CLI invocation

In `run_task()`, the `claude -p` calls (lines ~583 and ~654 in `bin/claude-runner.sh`) currently look like:

```bash
raw_output=$(echo "$prompt" | claude -p - $model_flag $perm_flag --output-format json 2>&1)
```

Build a `$fallback_flag` variable (similar to `$model_flag`) and append it:

```bash
local fallback_flag=""
if [[ -n "$task_fallback_model" ]]; then
  fallback_flag="--fallback-model $task_fallback_model"
elif [[ -n "$FALLBACK_MODEL" ]]; then
  fallback_flag="--fallback-model $FALLBACK_MODEL"
fi

raw_output=$(echo "$prompt" | claude -p - $model_flag $fallback_flag $perm_flag --output-format json 2>&1)
```

Apply `$fallback_flag` to both `claude -p` calls in `run_task()` (initial run and test-fix retry).

### Frontmatter parsing

In the frontmatter parsing section of `run_task()`, extract `fallback-model` alongside existing fields like `model`, `priority`, etc. Follow the same pattern used for other optional frontmatter fields.

## Affected files

- `bin/claude-runner.sh` — config loading, frontmatter parsing, claude invocation
- `tests/unit/` — add tests for fallback-model frontmatter parsing and flag construction

## Acceptance criteria

- `fallbackModel` in config is read and used as default fallback
- `fallback-model` frontmatter overrides global config
- `--fallback-model <model>` flag is passed to both `claude -p` invocations in `run_task()`
- When neither config nor frontmatter specifies fallback, no `--fallback-model` flag is passed
- Unit tests cover: frontmatter parsing, config fallback, per-task override, empty/missing values

## Constraints

- Do not modify rate limit retry logic (task 004 handles that separately)
- Do not change behavior when fallback-model is not configured
- Follow existing patterns for config reading and frontmatter parsing
