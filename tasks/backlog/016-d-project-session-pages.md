---
priority: medium
model: opus
estimated-cost: 3.0000
depends-on: 015
---

# Dispatch: Project detail and session detail pages

Build the project page (sessions + tasks + timeline) and session detail page (event stream). These are the primary drill-down views from the dashboard.

## Project detail page (`/projects/[slug]`)

### Layout

```
┌─────────────────────────────────────────────────────┐
│  [color] Project Name                    [Settings] │
│  Stack: Next.js / TypeScript                        │
│  Path: /home/sergey/projects/loom-ru                │
├──────────┬──────────┬───────────────────────────────┤
│ Sessions │  Tasks   │  Activity                     │
├──────────┴──────────┴───────────────────────────────┤
│                                                     │
│  [Sessions tab]                                     │
│  Active:                                            │
│  ┌──────────────────────────────────────────────┐   │
│  │ Session abc123 — feat/auth — opus — 45 min   │   │
│  │ Last: Edited src/auth.ts — 60% context       │   │
│  └──────────────────────────────────────────────┘   │
│                                                     │
│  Recent (last 7 days):                              │
│  ┌──────────────────────────────────────────────┐   │
│  │ Session def456 — main — sonnet — 12 min      │   │
│  │ Status: done — 3 tool calls — 8k tokens      │   │
│  └──────────────────────────────────────────────┘   │
│  ...                                                │
│                                                     │
│  [Tasks tab]                                        │
│  Kanban-style columns: Queued → Running → Done      │
│  + New Task button                                  │
│                                                     │
│  [Activity tab]                                     │
│  Timeline of all events for this project            │
└─────────────────────────────────────────────────────┘
```

### Tabs

1. **Sessions** — active sessions (realtime) + recent completed sessions (paginated)
2. **Tasks** — kanban view: queued | running | done | error columns. Drag-and-drop is NOT needed for MVP — just visual columns
3. **Activity** — chronological event feed for all sessions in this project

### Data

- Load project by slug: `supabase.from('projects').select().eq('slug', slug).single()`
- Sessions: `supabase.from('sessions').select().eq('project_id', project.id).order('started_at', {ascending: false})`
- Tasks: `supabase.from('tasks').select().eq('project_id', project.id)`
- Events: `supabase.from('events').select('*, sessions!inner(project_id)').eq('sessions.project_id', project.id)`

## Session detail page (`/sessions/[id]`)

### Layout

```
┌─────────────────────────────────────────────────────┐
│  Session abc123                                      │
│  Project: Loom.ru — Branch: feat/auth — Model: opus │
│  Machine: MacBook Pro — Started: 12:00 — Duration: 45m│
│  Status: [active]     Context: [████████░░] 80%     │
├─────────────────────────────────────────────────────┤
│                                                     │
│  Event Stream                                       │
│                                                     │
│  12:00:00  SESSION_START                             │
│            Started on feat/auth branch              │
│                                                     │
│  12:00:15  TOOL_USE — Read                          │
│            Read src/auth.ts (245 lines)             │
│                                                     │
│  12:00:30  TOOL_USE — Edit                          │
│            Edited src/auth.ts:42-58                  │
│            Duration: 120ms                           │
│                                                     │
│  12:01:00  TOOL_USE — Bash                          │
│            npm test                                  │
│            Duration: 3200ms                          │
│  ⚠️        Exit code 1 — 2 tests failed             │
│                                                     │
│  12:02:00  NOTIFICATION                              │
│  ⏳        Waiting for permission: git push          │
│                                                     │
│  ...                                                │
│                                                     │
│  Stats                                               │
│  Total events: 42 — Tool calls: 28                  │
│  Tokens used: 15,234 — Duration: 45 min             │
└─────────────────────────────────────────────────────┘
```

### Features

- **Event stream**: chronological list of all events for this session
- **Realtime updates**: new events appear at the bottom as they happen (Supabase Realtime on `events` table filtered by `session_id`)
- **Visual differentiation**:
  - Errors highlighted in red
  - Notifications/warnings in yellow
  - Tool uses in default color with tool name badge
  - Session start/stop in blue
- **Context usage bar**: visual progress bar showing `context_used` percentage
- **Stats summary**: total events, tool call count, tokens used, duration

### Data

- Session: `supabase.from('sessions').select('*, machines(name), projects(name, slug, color)').eq('id', id).single()`
- Events: `supabase.from('events').select().eq('session_id', id).order('created_at')`
- Realtime: subscribe to INSERT on `events` where `session_id = id`

## Affected files

- `dispatch/web/src/app/(dashboard)/projects/[slug]/page.tsx`
- `dispatch/web/src/app/(dashboard)/sessions/[id]/page.tsx`
- `dispatch/web/src/components/project/` — session-list, task-kanban, activity-timeline
- `dispatch/web/src/components/session/` — event-stream, session-header, stats-summary

## Acceptance criteria

- Project page loads with correct data for the given slug
- Three tabs (Sessions, Tasks, Activity) switch content correctly
- Active sessions update in realtime
- Task kanban shows tasks grouped by status
- Session detail shows full event stream
- New events appear in realtime without page refresh
- Context usage bar reflects current value
- Error events are visually highlighted
- 404 page if project slug or session id doesn't exist
- Both pages are responsive

## Constraints

- No drag-and-drop for kanban in MVP — just visual grouping
- Paginate events if session has > 100 events (load more button)
- Use Supabase Realtime, not polling
- Keep components reusable between project and dashboard views
