---
priority: high
model: opus
estimated-cost: 3.0000
---

# Add task dependency support via `depends-on` frontmatter field

Implement a `depends-on` frontmatter field that allows tasks to declare dependencies on other tasks. When a dependency fails, all dependent tasks should be automatically skipped instead of being executed.

## Context

Currently, `stopOnError: false` causes ALL remaining tasks to continue executing even if a task they logically depend on has failed. This wastes time and API credits. For example, if task `001-implement-feature` fails, task `003-add-tests-for-feature` will still run and inevitably fail too.

## Implementation

### 1. Frontmatter field

Add support for a `depends-on` field in task frontmatter. It accepts a comma-separated list of task slug prefixes (the numeric prefix or full slug):

```yaml
---
priority: medium
model: sonnet
depends-on: 001, 003
---
```

### 2. Parsing

In `bin/claude-runner.sh`:

- Add a new function `get_task_dependencies()` that extracts the `depends-on` field from frontmatter and returns a list of dependency prefixes/slugs
- The function should normalize the values (trim whitespace, handle both `001` and `001-some-slug` formats)

### 3. Dependency resolution in the main loop

In the main task execution loop (around line 928 in `main()`):

- Track failed task slugs/prefixes in an associative array (e.g., `declare -A FAILED_TASKS`)
- Before running each task, check its `depends-on` list against `FAILED_TASKS`
- If any dependency has failed, skip the task:
  - Log a warning: `"Skipping <task> because dependency <dep> failed"`
  - Record it in the report as `"skipped (dependency failed)"`
  - Mark the task as failed via `mark_task_failed` (so downstream dependents also get skipped)
  - Do NOT count it toward `TASKS_DONE`

### 4. Validation

In `validate_frontmatter()`:

- Validate that `depends-on` values match existing task files (warn if a dependency doesn't exist, but don't block execution)

### 5. Interaction with `stopOnError`

- When `stopOnError: true` (default): behavior is unchanged — runner stops at first failure regardless of dependencies
- When `stopOnError: false`: dependencies add selective skipping — only tasks that depend on the failed one are skipped, others continue normally

## Affected files

- `bin/claude-runner.sh` — main implementation
- `tests/unit/` — new tests for dependency parsing and validation
- `tests/integration/` — new tests for dependency resolution during execution

## Acceptance criteria

- Tasks can declare `depends-on: 001, 003` in frontmatter
- When `stopOnError: false` and task `001` fails, tasks depending on `001` are skipped with a clear log message
- Skipped-due-to-dependency tasks appear as "skipped" in the final report
- Skipped tasks are also added to `FAILED_TASKS` so transitive dependencies are skipped too (if A→B→C and A fails, both B and C are skipped)
- When `stopOnError: true`, behavior is unchanged
- All new functionality has bats tests
- Existing tests continue to pass

## Constraints

- Do not change existing frontmatter fields or their parsing
- Do not change the default behavior when `depends-on` is not specified
- Keep the dependency resolution simple — no circular dependency detection needed (tasks are sorted by priority/filename, so they execute in order)
