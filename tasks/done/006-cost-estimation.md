---
cost: 0.5797
priority: medium
model: sonnet
---

# Add cost estimation script and integrate into cr-task-create skill

Create a script `bin/estimate-cost.sh` that estimates the cost of a task based on the chosen model. The script computes average actual cost per model from completed tasks in the done directory. When historical data is unavailable, it falls back to hardcoded default estimates.

Then update the `/cr-task-create` skill (`skills/cr-task-create/SKILL.md`) to call this script and write the result as `estimated-cost` in the new task's frontmatter.

## Script: `bin/estimate-cost.sh`

### Interface

```bash
bin/estimate-cost.sh --model <model> [--done-dir <path>]
# Outputs a single number (USD, 4 decimal places) to stdout
# Example: 1.2500
```

- `--model` (required): model alias (`opus`, `sonnet`, `haiku`, `opusplan`) or full model ID
- `--done-dir` (optional): path to done tasks directory, default `./tasks/done`

### Logic

1. Scan all `*.md` files in `--done-dir`
2. For each file, parse frontmatter fields `model` and `cost` (both must be present to count)
3. Group costs by model, compute the average for the requested model
4. If no historical data exists for the requested model, use hardcoded defaults:
   - `haiku`: 0.0500
   - `sonnet`: 0.5000
   - `opus`: 3.0000
   - `opusplan`: 4.0000
   - Unknown/full model IDs: 1.0000
5. Output the estimate to stdout (4 decimal places, no `$` sign)
6. Exit 0 on success, exit 1 on missing `--model` argument

### Implementation notes

- Use the same frontmatter parsing approach as `bin/claude-runner.sh` (sed-based extraction between `---` delimiters)
- The script must be executable and have a bash shebang
- No dependencies beyond bash 4+ and standard coreutils (awk/sed/grep)
- Do NOT use jq (keep it lightweight)

## Skill update: `skills/cr-task-create/SKILL.md`

Add instructions to the skill so that when creating a task:

1. After choosing the model, run `bin/estimate-cost.sh --model <chosen-model> --done-dir <doneDir-from-config>`
2. Add `estimated-cost: <result>` to the task's frontmatter
3. If the script is not found or fails, skip the field silently (don't block task creation)

Add `estimated-cost` to the frontmatter template in the skill.

## Tests

Add bats tests in `tests/unit/test_estimate_cost.bats`:

- Returns default estimate when done dir is empty
- Returns default estimate when done dir has tasks without cost field
- Computes average from multiple done tasks with cost data for matching model
- Ignores tasks with different model
- Exits 1 when --model is not provided
- Handles mixed tasks (some with cost, some without)

## Details

- Affected files: `bin/estimate-cost.sh` (new), `skills/cr-task-create/SKILL.md`, `tests/unit/test_estimate_cost.bats` (new)
- Acceptance criteria:
  - `bin/estimate-cost.sh --model sonnet` returns a valid number
  - `bin/estimate-cost.sh --model sonnet --done-dir ./tasks/done` uses historical data when available
  - All new bats tests pass (`npm test`)
  - Skill SKILL.md includes instructions to call the script and write `estimated-cost`
- Constraints: do not modify `bin/claude-runner.sh`
