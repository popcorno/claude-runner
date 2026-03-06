---
priority: high
model: opus
estimated-cost: 2.0000
---

# Dispatch: Supabase schema, migrations, and project setup

Set up the Dispatch Supabase project with all database tables, RLS policies, indexes, and initial Edge Function for health checks. This is the foundation for all backend work.

## Context

Dispatch is a web service for managing and monitoring Claude Code sessions across multiple machines and projects. This task creates the database layer. The schema is defined in `docs/dispatch-architecture.md`.

## Deliverables

### 1. Supabase project initialization

Create a new directory `dispatch/` at the repo root with:

```
dispatch/
  supabase/
    config.toml
    migrations/
      001_initial_schema.sql
    seed.sql              (optional — dev seed data)
  README.md               (setup instructions)
```

Initialize with `supabase init` (or create the structure manually if CLI is not available).

### 2. Migration: `001_initial_schema.sql`

Create all tables as specified in the architecture doc:

**`machines`** — registered machines
- `id` uuid PK
- `user_id` uuid FK to auth.users, NOT NULL
- `name` text NOT NULL
- `hostname` text NOT NULL
- `machine_key` text UNIQUE NOT NULL
- `last_heartbeat` timestamptz
- `is_online` boolean DEFAULT false
- `meta` jsonb DEFAULT '{}'
- `created_at` timestamptz DEFAULT now()

**`projects`** — tracked projects
- `id` uuid PK
- `user_id` uuid FK to auth.users, NOT NULL
- `name` text NOT NULL
- `slug` text UNIQUE NOT NULL
- `repo_path` text
- `stack` text
- `color` text DEFAULT '#3B82F6'
- `created_at` timestamptz DEFAULT now()

**`sessions`** — Claude Code sessions
- `id` uuid PK
- `user_id` uuid FK to auth.users, NOT NULL
- `machine_id` uuid FK to machines, NOT NULL
- `project_id` uuid FK to projects
- `session_code` text NOT NULL
- `branch` text
- `status` text DEFAULT 'active' (active, idle, waiting, done, error, stale)
- `task_description` text
- `model` text
- `context_used` integer
- `tokens_used` integer DEFAULT 0
- `started_at` timestamptz DEFAULT now()
- `last_event_at` timestamptz DEFAULT now()
- `finished_at` timestamptz
- `error_summary` text
- `meta` jsonb DEFAULT '{}'

**`events`** — session lifecycle events
- `id` bigint GENERATED ALWAYS AS IDENTITY PK
- `session_id` uuid FK to sessions, NOT NULL
- `event_type` text NOT NULL
- `tool_name` text
- `summary` text
- `duration_ms` integer
- `details` jsonb DEFAULT '{}'
- `created_at` timestamptz DEFAULT now()

**`tasks`** — task queue
- `id` uuid PK
- `user_id` uuid FK to auth.users, NOT NULL
- `project_id` uuid FK to projects, NOT NULL
- `machine_id` uuid FK to machines (nullable — any machine)
- `title` text NOT NULL
- `prompt` text NOT NULL
- `priority` integer DEFAULT 0
- `depends_on` uuid[]
- `status` text DEFAULT 'queued' (queued, running, done, error, cancelled)
- `session_id` uuid FK to sessions
- `max_turns` integer DEFAULT 50
- `scheduled_at` timestamptz
- `started_at` timestamptz
- `finished_at` timestamptz
- `result_summary` text
- `error_message` text
- `created_at` timestamptz DEFAULT now()

### 3. Indexes

```sql
CREATE INDEX idx_events_session_time ON events (session_id, created_at DESC);
CREATE INDEX idx_events_type ON events (event_type, created_at DESC);
CREATE INDEX idx_sessions_status ON sessions (user_id, status);
CREATE INDEX idx_tasks_status ON tasks (status, scheduled_at);
CREATE INDEX idx_machines_key ON machines (machine_key);
```

### 4. RLS policies

Enable RLS on all tables. Each table gets a policy restricting access to the owning user:

- `machines`, `projects`, `sessions`, `tasks`: `auth.uid() = user_id`
- `events`: `session_id IN (SELECT id FROM sessions WHERE user_id = auth.uid())`

Additionally, add a service-role bypass policy or use the service key for Edge Functions that ingest data from agents.

### 5. Realtime

Enable Supabase Realtime on `sessions`, `events`, and `tasks` tables.

## Affected files

- `dispatch/supabase/config.toml`
- `dispatch/supabase/migrations/001_initial_schema.sql`
- `dispatch/README.md`

## Acceptance criteria

- All five tables are created with correct types, constraints, and defaults
- RLS is enabled on all tables with correct policies
- Indexes are created for performance-critical queries
- Migration applies cleanly on a fresh Supabase project (`supabase db reset`)
- README has clear setup instructions (create Supabase project, link, apply migrations)
- Realtime is enabled for sessions, events, and tasks

## Constraints

- Follow Supabase conventions for migration naming and structure
- Use `gen_random_uuid()` for UUID defaults (Supabase default)
- Do not add application logic to the database (no triggers, no stored procedures) — keep it simple
- The `dispatch/` directory is self-contained; it does not affect claude-runner's own files
