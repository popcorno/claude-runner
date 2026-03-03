# claude-runner

CLI tool for automated sequential task execution via Claude Code.

## Architecture

Single bash script (`bin/claude-runner.sh`) — no dependencies beyond bash 4+, jq, git, and Claude Code CLI.

### Key functions

- `load_config()` — reads `claude-runner.config.json` or `.claude-runner.json`
- `collect_tasks()` — finds `.md` files in tasksDir, validates frontmatter, sorts by priority then filename
- `run_task()` — executes a single task: parse frontmatter → build prompt → call `claude -p` → run tests → retry on failure → commit or rollback
- `validate_frontmatter()` — validates priority/model/skip-tests values, returns default on invalid (warnings go to stderr)
- `set_frontmatter_status()` — updates frontmatter `status` field (for `doneStrategy: "status"`)
- `mark_task_done()` / `mark_task_failed()` — move file or update status depending on strategy
- `list_tasks()` — display tasks from a directory (used for `--list` and `--list-backlog`)

### Flow

```
main → parse_args → load_config → collect_tasks → run_task (loop)
                                                    ↓
                                              claude -p (stdin)
                                                    ↓
                                              test → retry? → commit/rollback
```

## Testing

```bash
npm test          # runs: bats --recursive tests/
bats tests/unit/  # unit tests only
```

Tests use [bats-core](https://github.com/bats-core/bats-core). The script is sourced in tests via `BASH_SOURCE` guard (won't run `main` when sourced).

### Test structure

- `tests/unit/` — frontmatter parsing, validation, format_time, flag resolution
- `tests/integration/` — config loading, task collection, task lifecycle
- `tests/e2e/` — CLI flags, argument parsing, regression tests

## Skills

Skills live in `skills/` and follow Claude Code skill format (directory with `SKILL.md`). Users copy them to `.claude/skills/` in their projects.

Available: `/create-task`, `/plan-tasks`, `/promote`, `/retry-failed`

## Directories

- `tasksDir` (default `./tasks/open`) — tasks for execution
- `backlogDir` (default `./tasks/backlog`) — ideas/drafts, not executed by runner
- `doneDir` (default `./tasks/done`) — completed tasks
- `failedDir` (default `./tasks/failed`) — failed tasks

## Conventions

- Commit messages: conventional commits (`feat:`, `fix:`, `test:`, `docs:`, `chore:`)
- All warnings from functions called inside `$()` must write to stderr (`>&2`)
- Config values parsed with `jq -r '.field | values'` (not `// empty` — that drops boolean `false`)
