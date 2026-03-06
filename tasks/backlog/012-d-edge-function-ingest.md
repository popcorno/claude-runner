---
priority: high
model: opus
estimated-cost: 1.5000
depends-on: 011
---

# Dispatch: Edge Function for event ingestion

Create a Supabase Edge Function that serves as the single entry point for all agent-to-backend communication. Agents authenticate with their `machine_key` and send events, heartbeats, and session updates through this function.

## Context

Agents on remote machines need to report events to Dispatch. Instead of giving agents direct Supabase access (anon key + RLS), we use an Edge Function as a secure proxy. The agent sends its `machine_key` in the header, and the function validates it, resolves the `user_id` and `machine_id`, and performs the database operations.

## Endpoints

Single Edge Function `ingest` handling different event types via the `event_type` field in the request body.

### Request format

```
POST /functions/v1/ingest
Headers:
  x-machine-key: <machine_key>
  Content-Type: application/json

Body:
  {
    "event_type": "session_start" | "tool_use" | "heartbeat" | "notification" | "stop" | "task_update",
    "session_code": "abc123",
    "data": { ... }
  }
```

### Event handlers

**`session_start`** — Creates or updates a session record
```json
{
  "event_type": "session_start",
  "session_code": "abc123",
  "data": {
    "project_slug": "loom-ru",
    "branch": "feat/new-feature",
    "model": "claude-sonnet-4",
    "task_description": "Implement user auth"
  }
}
```
Action: UPSERT into `sessions` (by `session_code` + `machine_id`). Set status = 'active'.

**`tool_use`** — Records a tool use event
```json
{
  "event_type": "tool_use",
  "session_code": "abc123",
  "data": {
    "tool_name": "Edit",
    "summary": "Edited src/auth.ts",
    "duration_ms": 150
  }
}
```
Action: INSERT into `events`. UPDATE `sessions.last_event_at` and `sessions.status = 'active'`.

**`heartbeat`** — Machine is alive
```json
{
  "event_type": "heartbeat",
  "data": {
    "active_sessions": 2,
    "cpu_usage": 45
  }
}
```
Action: UPDATE `machines.last_heartbeat = now()`, `machines.is_online = true`. Optionally store meta.

**`notification`** — Claude Code sent a notification (permission request, idle, etc.)
```json
{
  "event_type": "notification",
  "session_code": "abc123",
  "data": {
    "type": "permission",
    "message": "Claude wants to run: rm -rf /tmp/test"
  }
}
```
Action: INSERT into `events`. UPDATE `sessions.status` based on notification type ('waiting' for permission, 'idle' for idle).

**`stop`** — Session ended
```json
{
  "event_type": "stop",
  "session_code": "abc123",
  "data": {
    "tokens_used": 15000,
    "error": null
  }
}
```
Action: INSERT into `events`. UPDATE `sessions.status = 'done'` (or 'error' if `data.error` is set), `sessions.finished_at = now()`.

**`task_update`** — Task status change (from runner hooks)
```json
{
  "event_type": "task_update",
  "data": {
    "task_id": "uuid-here",
    "status": "done",
    "result_summary": "Feature implemented, 12 tests passing",
    "duration_seconds": 120,
    "attempts": 1
  }
}
```
Action: UPDATE `tasks` with new status, result, timing.

## Implementation

### File structure

```
dispatch/supabase/functions/
  ingest/
    index.ts
```

### Authentication flow

```typescript
// 1. Extract machine_key from header
const machineKey = req.headers.get('x-machine-key')
if (!machineKey) return new Response('Unauthorized', { status: 401 })

// 2. Look up machine
const { data: machine } = await supabase
  .from('machines')
  .select('id, user_id')
  .eq('machine_key', machineKey)
  .single()

if (!machine) return new Response('Invalid machine key', { status: 403 })

// 3. Use machine.user_id for all subsequent operations
```

Use the Supabase service role client inside the Edge Function (it bypasses RLS since we've already authenticated via machine_key).

### Error handling

- Return 401 for missing `x-machine-key`
- Return 403 for invalid machine key
- Return 400 for missing/invalid `event_type` or `session_code`
- Return 500 for database errors (with generic message, log details)
- Always return JSON: `{ "ok": true }` or `{ "error": "message" }`

### Rate limiting (future)

For MVP, no rate limiting. Add a TODO comment for future rate limiting per machine_key.

## Affected files

- `dispatch/supabase/functions/ingest/index.ts`

## Acceptance criteria

- Edge Function deploys and responds to POST requests
- Authentication via `x-machine-key` header works
- All six event types are handled correctly
- Invalid/missing auth returns 401/403
- Invalid payloads return 400 with descriptive error
- Database records are created/updated correctly
- `sessions.last_event_at` is updated on every session-related event
- Function is idempotent where possible (e.g., duplicate heartbeats are fine)

## Constraints

- Use Deno (Supabase Edge Functions runtime)
- Use `@supabase/supabase-js` for database access
- Service role key for DB operations (bypasses RLS — we authenticate via machine_key)
- Keep the function under 300 lines — simple routing, no over-engineering
- No external dependencies beyond Supabase SDK
