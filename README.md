# claude-runner

CLI tool for automated sequential task execution via [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

Define your tasks as markdown files, and `claude-runner` will execute them one by one — running Claude with a clean context for each task, testing, retrying on failure, and committing results automatically.

## Installation

### From GitHub (npm)

```bash
npm install -g github:YOUR_USERNAME/claude-runner
```

### Local development (npm link)

```bash
git clone https://github.com/YOUR_USERNAME/claude-runner.git
cd claude-runner
npm link
```

### Manual (copy to PATH)

```bash
cp bin/claude-runner.sh /usr/local/bin/claude-runner
chmod +x /usr/local/bin/claude-runner
```

## Quick Start

**1. Create a tasks directory in your project:**

```bash
mkdir -p tasks/{open,done,failed}
```

**2. Add a task file** `tasks/open/001-add-feature.md`:

```markdown
---
priority: high
---

# Add user authentication

Implement JWT-based authentication middleware.

## Details

- Create src/middleware/auth.ts
- Add login and register endpoints
- Write tests for all endpoints
```

**3. Run:**

```bash
claude-runner
```

That's it. `claude-runner` will pick up all tasks from `tasks/open/`, execute them via Claude Code, run tests, and commit the results. Completed tasks are moved to `tasks/done/`, failed ones to `tasks/failed/`.

## Folder Structure

By default, `claude-runner` uses a folder-based workflow:

```
tasks/
  open/       ← tasks to execute
  done/       ← successfully completed tasks (moved automatically)
  failed/     ← tasks that failed after all retries (moved automatically)
```

This keeps your task board clean — you can see at a glance what's pending, done, and broken.

Alternatively, set `"doneStrategy": "status"` to use the legacy mode where task status is tracked via a `status` field in YAML frontmatter (the file stays in place and gets `status: done` written into it).

## Configuration

Place `claude-runner.config.json` or `.claude-runner.json` in your project root.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `tasksDir` | string | `"./tasks/open"` | Directory containing open task files |
| `doneDir` | string | `"./tasks/done"` | Directory for completed tasks |
| `failedDir` | string | `"./tasks/failed"` | Directory for failed tasks |
| `doneStrategy` | `"move"` \| `"status"` | `"move"` | How to mark tasks as done (see below) |
| `defaultModel` | string | `"opus"` | Default Claude model (see Model Aliases) |
| `testCommand` | string | `"npm test"` | Command to run tests after each task |
| `autoCommit` | boolean | `true` | Auto git commit after successful task |
| `commitPrefix` | string | `"feat"` | Prefix for auto-generated commit messages |
| `maxRetries` | number | `2` | Retry attempts when tests fail |
| `systemPrompt` | string | `""` | System prompt prepended to every task |
| `stopOnError` | boolean | `true` | Stop on failure (`true`) or skip and continue (`false`) |
| `allowDangerousMode` | boolean | `true` | Pass `--dangerously-skip-permissions` to Claude (see below) |

### Done Strategy

- **`"move"`** (default) — completed tasks are moved from `tasksDir` to `doneDir`. Failed tasks are moved to `failedDir`. All files in `tasksDir` are treated as open tasks (no `status` field needed in frontmatter).
- **`"status"`** — tasks stay in place. The script filters by `status: open` in frontmatter and writes `status: done` after success. `doneDir` and `failedDir` are ignored.

### Permission Mode

- **`"allowDangerousMode": true`** (default) — passes `--dangerously-skip-permissions` to Claude, allowing it to execute any tool (file edits, bash commands, etc.) without confirmation. This is the expected mode for an autonomous runner.
- **`"allowDangerousMode": false`** — Claude will use the permission settings from your project's `.claude/settings.json`. Use this if you want to restrict what Claude can do (e.g., block destructive bash commands, limit file edits to certain directories).

**Example config:**

```json
{
  "tasksDir": "./tasks/open",
  "doneDir": "./tasks/done",
  "failedDir": "./tasks/failed",
  "doneStrategy": "move",
  "defaultModel": "sonnet",
  "testCommand": "npm test",
  "autoCommit": true,
  "commitPrefix": "feat",
  "maxRetries": 2,
  "systemPrompt": "You are working on a TypeScript project. Follow existing patterns.",
  "stopOnError": true,
  "allowDangerousMode": true
}
```

## Task File Format

Each task is a `.md` file. Frontmatter is optional — a plain markdown file with just a `# Title` and description works fine (defaults will be used for all settings).

**Minimal task (no frontmatter):**

```markdown
# Add logging middleware

Add a request logging middleware to src/middleware/logger.ts.
Log method, URL, status code, and response time.
```

**Full task (with frontmatter):**

```markdown
---
priority: high
model: opus
commit-message: "feat: add user model"
---

# Task title goes here

Task description and instructions for Claude.
```

### Frontmatter Fields

| Field | Type | Default | Description |
|---|---|---|---|
| `priority` | `high` \| `medium` \| `low` | `medium` | Execution order: high first, then medium, then low |
| `status` | `open` \| `done` \| `skip` | `open` | Only used with `doneStrategy: "status"` |
| `model` | string | (from config) | Override model for this task |
| `skip-tests` | boolean | `false` | Skip test execution for this task |
| `commit-message` | string | auto-generated | Custom commit message |
| `created` | string | — | Informational, not used by the script |

### Priority Sorting

Tasks are sorted by priority first (`high` > `medium` > `low`), then alphabetically by filename within each priority group. Use numeric prefixes (e.g., `001-`, `002-`) to control order within the same priority.

## Model Aliases

`claude-runner` supports Claude Code model aliases:

| Alias | Description |
|---|---|
| `opus` | Claude Opus — most capable model |
| `sonnet` | Claude Sonnet — balanced speed and capability |
| `haiku` | Claude Haiku — fastest model |
| `opusplan` | Hybrid: Opus for planning, Sonnet for code execution |

You can also use full model identifiers like `claude-opus-4-6` or `claude-sonnet-4-6`.

Set the model per-task in frontmatter or globally via `defaultModel` in config.

## CLI Options

| Flag | Description |
|---|---|
| `[tasks-dir]` | Tasks directory (positional argument, overrides config) |
| `--task <file>` | Run a single task file |
| `--dry-run` | Show execution plan without running anything |
| `--from <prefix>` | Start from task matching prefix (skip earlier tasks) |
| `--verbose` | Verbose output |
| `--list` | List open tasks and exit |
| `--version` | Show version |
| `--help` | Show help |

## Examples

### Run all open tasks

```bash
claude-runner
```

### Run tasks from a specific directory

```bash
claude-runner ./sprint-3/open
```

### Preview execution plan

```bash
claude-runner --dry-run
```

Output:
```
Execution plan (dry run):

  1. 001-setup-project      high   opus     Initialize project structure  [tests]
  2. 002-add-user-model     medium sonnet   Create User model             [tests]

  Strategy: move | Model: sonnet | Tests: npm test | Retries: 2
```

### Run a single task

```bash
claude-runner --task ./tasks/open/003-add-auth.md
```

### Start from a specific task

```bash
claude-runner --from 003
```

### List open tasks

```bash
claude-runner --list
```

### Use in a CI-like workflow

```bash
# Create tasks programmatically
for issue in $(gh issue list --label "auto" --json number -q '.[].number'); do
  gh issue view "$issue" --json title,body \
    -q '"---\npriority: medium\n---\n\n# " + .title + "\n\n" + .body' \
    > "tasks/open/$(printf '%03d' $issue)-issue.md"
done

# Run all tasks
claude-runner --verbose
```

## How It Works

1. **Folder-based workflow** — tasks live in `tasks/open/`. On success, they are moved to `tasks/done/`. On failure (after exhausting retries), they are moved to `tasks/failed/`. This gives you a clear kanban-style view of task status.

2. **Clean context per task** — each task runs as a separate `claude -p` invocation with no shared context between tasks. This ensures Claude focuses on one task at a time.

3. **Priority-based ordering** — tasks are sorted by priority (`high` → `medium` → `low`), then by filename within the same priority.

4. **Automatic testing** — after Claude completes a task, the configured test command runs. If tests fail, Claude gets another chance to fix the code (up to `maxRetries` times).

5. **Rollback on failure** — if all retry attempts are exhausted, code changes are rolled back via `git checkout . && git clean -fd`, and the task file is moved to `tasks/failed/`.

6. **Auto-commit** — on success, all changes (including the task file move) are staged and committed with either a custom or auto-generated message.

7. **Stop or continue** — when `stopOnError` is `true` (default), execution stops at the first failed task. Set it to `false` to skip failures and continue with remaining tasks.

## Claude Code Skills

`claude-runner` includes Claude Code skills (slash commands) for managing tasks. Copy the `skills/` contents into your project's `.claude/skills/`:

```bash
cp -r node_modules/claude-runner/skills/* .claude/skills/
```

Or if you cloned the repo:

```bash
cp -r /path/to/claude-runner/skills/* .claude/skills/
```

Each skill is a directory with a `SKILL.md` file following the Claude Code skills format.

### Available skills

| Skill | Description |
|---|---|
| `/create-task` | Create a single task interactively. Detects next number, generates frontmatter and detailed instructions |
| `/plan-tasks` | Break down a high-level goal into a series of sequential tasks. Shows plan for approval before creating files |
| `/retry-failed` | Move failed tasks back to `open/` for another attempt |

### Usage

```bash
# In Claude Code:
/create-task Add email validation to the User model
/plan-tasks Implement full JWT authentication with login, register, and middleware
/retry-failed
```

## Requirements

- **[Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code)** — the `claude` command must be available in PATH
- **[jq](https://jqlang.github.io/jq/)** — for JSON config parsing (`brew install jq` / `apt install jq`)
- **[git](https://git-scm.com/)** — for commits and rollbacks
- **bash** 4.0+ — the script uses bash arrays and associative features

## License

MIT
