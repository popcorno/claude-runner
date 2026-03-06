---
priority: high
model: opus
estimated-cost: 4.0000
depends-on: 012
---

# Dispatch: Agent CLI for machine registration and event reporting

Create the `dispatch` CLI tool that runs on each machine. It handles machine registration, Claude Code hooks integration, event reporting to the Dispatch backend, and background task execution.

## Context

The Dispatch Agent is the bridge between a local machine running Claude Code and the Dispatch web service. It installs as a CLI tool, configures Claude Code hooks to report events, sends heartbeats, and listens for tasks from the queue.

## Commands

### `dispatch init`

Interactive setup that registers a machine with Dispatch.

```bash
dispatch init --name "MacBook Pro" --url https://xyz.supabase.co --anon-key <key>
```

Flow:
1. Prompt for Supabase URL and anon key (or accept via flags)
2. Prompt for user login (email/password) — authenticate via Supabase Auth
3. Register the machine: INSERT into `machines` table, receive `machine_key`
4. Save config to `~/.dispatch/config.json`:
   ```json
   {
     "supabase_url": "https://xyz.supabase.co",
     "machine_key": "mk_xxxxxxxxxxxx",
     "machine_id": "uuid",
     "machine_name": "MacBook Pro",
     "ingest_url": "https://xyz.supabase.co/functions/v1/ingest"
   }
   ```
5. Offer to configure Claude Code hooks (add to `~/.claude/settings.json`)

### `dispatch report <event_type>`

Called by Claude Code hooks. Reads hook context from stdin, enriches it, and sends to the ingest endpoint.

```bash
# Called by Claude Code hook — stdin contains hook JSON context
dispatch report session_start
dispatch report tool_use
dispatch report notification
dispatch report stop
```

Flow:
1. Read JSON from stdin (Claude Code hook payload)
2. Load config from `~/.dispatch/config.json`
3. Build the ingest payload (extract relevant fields from hook context)
4. POST to `ingest_url` with `x-machine-key` header
5. Exit 0 regardless of success/failure (hooks must not block Claude Code)

### `dispatch worker start`

Background daemon that sends heartbeats and polls for tasks.

```bash
dispatch worker start          # foreground (for testing)
dispatch worker start --daemon # background (production)
dispatch worker stop           # stop the daemon
dispatch worker status         # show worker status
```

Worker loop:
1. Every 30 seconds: send heartbeat to ingest endpoint
2. Every 10 seconds: check for queued tasks assigned to this machine
   - Query tasks where `machine_id = this_machine OR machine_id IS NULL` AND `status = 'queued'` AND `scheduled_at <= now()`
   - Check `depends_on` — all dependencies must be in `done` status
   - Claim the task (UPDATE status = 'running')
   - Execute: materialize task as `.md` file → run `claude-runner --run-single` (depends on d-002)
   - Report result back via ingest endpoint (`task_update` event)
3. Configurable parallelism (default: 1 concurrent task)

### `dispatch projects`

List projects associated with the user (for quick reference).

```bash
dispatch projects              # list all projects
dispatch projects add --name "Loom.ru" --slug loom-ru --path /home/sergey/projects/loom-ru
```

### `dispatch status`

Show current machine status: online/offline, active sessions, running tasks.

## Implementation

### Tech stack

- **Node.js** (single package, publishable to npm as `@dispatch/agent` or `dispatch-agent`)
- Minimal dependencies: `node-fetch` (or native fetch in Node 18+), `commander` for CLI
- No framework overhead

### Project structure

```
dispatch/agent/
  package.json
  src/
    cli.ts              — commander setup, command routing
    commands/
      init.ts           — machine registration
      report.ts         — event reporting (called by hooks)
      worker.ts         — background task runner
      projects.ts       — project management
      status.ts         — machine status
    lib/
      config.ts         — read/write ~/.dispatch/config.json
      api.ts            — HTTP client for ingest endpoint
      hooks.ts          — Claude Code hooks configuration
      task-runner.ts    — materialize task → run claude-runner → report
    types.ts            — TypeScript interfaces
```

### Claude Code hooks setup

The `dispatch init` command adds hooks to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [{ "hooks": [{ "type": "command", "command": "dispatch report session_start" }] }],
    "PostToolUse": [{ "matcher": "Edit|Write|MultiEdit|Bash", "hooks": [{ "type": "command", "command": "dispatch report tool_use" }] }],
    "Notification": [{ "hooks": [{ "type": "command", "command": "dispatch report notification" }] }],
    "Stop": [{ "hooks": [{ "type": "command", "command": "dispatch report stop" }] }]
  }
}
```

Must merge with existing hooks, not overwrite.

### Task materialization

When the worker picks up a task from the queue:

1. Create a temp `.md` file with frontmatter from task fields:
   ```markdown
   ---
   priority: {task.priority}
   model: {task.model || 'sonnet'}
   ---

   # {task.title}

   {task.prompt}
   ```
2. `cd` to the project's `repo_path`
3. Run `claude-runner --run-single /tmp/dispatch-task-{id}.md --output-format json` (depends on d-002, d-003)
4. Parse JSON output for result
5. Report back via `task_update` event
6. Clean up temp file

## Affected files

- `dispatch/agent/` — entire new package

## Acceptance criteria

- `dispatch init` registers a machine and saves config
- `dispatch report` sends events to the ingest endpoint from Claude Code hooks
- `dispatch worker start` sends heartbeats and executes queued tasks
- Task execution uses claude-runner via `--run-single` and `--output-format json`
- Worker respects `depends_on` (skips tasks with unfinished dependencies)
- Worker handles errors gracefully (task failure doesn't crash the worker)
- All commands have `--help` with usage information
- `dispatch report` never blocks (exits 0 regardless of API success/failure)

## Constraints

- Must work on macOS and Linux
- Node.js 18+ (for native fetch)
- Claude Code CLI and claude-runner must be installed on the machine
- Config stored in `~/.dispatch/` (not project-specific)
- `dispatch report` must complete in under 1 second (non-blocking hook)
