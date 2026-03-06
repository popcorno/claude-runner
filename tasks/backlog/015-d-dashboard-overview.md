---
priority: medium
model: opus
estimated-cost: 2.5000
depends-on: 014
---

# Dispatch: Dashboard overview page

Build the main dashboard page that shows a bird's-eye view of all projects, active sessions, machines, and recent activity. This is the first thing users see after login.

## Context

The overview page answers the question: "What's happening across all my projects right now?" It's especially useful in the morning after overnight task runs — the user opens the dashboard and immediately sees what completed, what failed, and where attention is needed.

## Layout

```
┌─────────────────────────────────────────────────────┐
│  Overview                                    [Today] │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌─── Machines ──┐  ┌─── Sessions ──┐  ┌── Tasks ──┐
│  │ 2 online      │  │ 3 active      │  │ 5 queued  │
│  │ 1 offline     │  │ 1 waiting     │  │ 2 running │
│  └───────────────┘  └───────────────┘  └───────────┘
│                                                     │
│  Active Sessions                                    │
│  ┌──────────────────────────────────────────────┐   │
│  │ [loom-ru] feat/auth — MacBook — opus         │   │
│  │ Editing src/auth.ts — 45% context — 12 min   │   │
│  ├──────────────────────────────────────────────┤   │
│  │ [deploy-saas] main — Linux — sonnet          │   │
│  │ Running tests — 20% context — 3 min          │   │
│  └──────────────────────────────────────────────┘   │
│                                                     │
│  Projects                                           │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐    │
│  │  Loom.ru   │  │ DeploySaas │  │  Runner    │    │
│  │  2 sessions│  │  1 session │  │  idle      │    │
│  │  3 tasks   │  │  0 tasks   │  │  2 tasks   │    │
│  └────────────┘  └────────────┘  └────────────┘    │
│                                                     │
│  Recent Activity                                    │
│  12:05  [loom-ru] Task "Add auth" completed         │
│  11:42  [runner] Task "Fix tests" failed            │
│  11:30  [deploy-saas] Session started               │
│  ...                                                │
└─────────────────────────────────────────────────────┘
```

## Components

### 1. Stats cards row
- Machines: online/offline count with status dots
- Sessions: active/waiting/idle count
- Tasks: queued/running count
- Each card links to its respective list page

### 2. Active sessions list
- Show all sessions with status != 'done'
- For each: project name (colored badge), branch, machine, model
- Latest event summary, context usage %, duration
- Click → session detail page
- **Realtime**: updates via Supabase subscription on `sessions` table

### 3. Project cards grid
- All user's projects as cards
- Each card shows: name, color dot, active session count, queued task count
- Click → project detail page

### 4. Recent activity feed
- Last 20 events across all sessions
- Grouped by time, showing: timestamp, project, event summary
- Color-coded: green for done, red for errors, yellow for warnings
- Auto-updates via Supabase Realtime on `events` table

## Data fetching

- Stats, projects, and recent activity: Server Component with `supabase.from(...).select()`
- Active sessions and event feed: Client Component with Supabase Realtime subscriptions

## Affected files

- `dispatch/web/src/app/(dashboard)/page.tsx` — main page
- `dispatch/web/src/components/dashboard/` — stats-cards, active-sessions, project-cards, activity-feed

## Acceptance criteria

- Dashboard loads with real data from Supabase
- Stats cards show correct counts
- Active sessions update in realtime (no page refresh needed)
- Project cards show correct session and task counts
- Activity feed shows recent events with correct formatting
- Clicking a session card navigates to session detail
- Clicking a project card navigates to project detail
- Page is responsive (cards stack on mobile)
- Empty states are handled (no projects, no sessions, etc.)

## Constraints

- Use Server Components for initial data load, Client Components only for realtime parts
- No polling — use Supabase Realtime exclusively
- Keep queries efficient (use counts, not full selects where possible)
- Follow shadcn/ui patterns for cards, badges, and lists
