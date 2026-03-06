---
priority: low
model: sonnet
estimated-cost: 1.5000
depends-on: 012, 015
---

# Dispatch: Realtime subscriptions and stale session detection

Implement server-side stale session detection via Edge Function cron job and ensure all realtime subscriptions across the web app are robust and performant.

## Stale session detection

### Problem

If a machine goes offline (crash, network loss, laptop lid closed), its sessions stay in 'active' or 'waiting' status forever. Users need to know these sessions are stale.

### Solution: Edge Function cron

Create a Supabase Edge Function `check-stale-sessions` that runs every minute via pg_cron or Supabase's built-in cron:

```sql
-- Mark sessions as stale if no events for 5 minutes
UPDATE sessions
SET status = 'stale'
WHERE status IN ('active', 'waiting', 'idle')
  AND last_event_at < now() - interval '5 minutes';

-- Mark machines as offline if no heartbeat for 2 minutes
UPDATE machines
SET is_online = false
WHERE is_online = true
  AND last_heartbeat < now() - interval '2 minutes';
```

### Edge Function implementation

```
dispatch/supabase/functions/check-stale/index.ts
```

- Triggered by cron (configure in Supabase dashboard or via `supabase/config.toml`)
- Uses service role key
- Logs how many sessions/machines were updated
- Returns summary JSON

### Stale session UI

- Stale sessions show a warning badge in the dashboard
- Color: gray or orange, distinct from active (green) and error (red)
- Tooltip: "No activity for 5+ minutes — session may have disconnected"
- Action button: "Mark as done" (manually close a stale session)

## Realtime subscription audit

Ensure all realtime subscriptions across the app are:

1. **Properly scoped** — filter by `user_id` to avoid receiving other users' data
2. **Properly cleaned up** — unsubscribe on component unmount
3. **Reconnection-resilient** — handle Supabase channel reconnects gracefully

### Subscription locations

| Page | Table | Event | Filter |
|------|-------|-------|--------|
| Dashboard | sessions | UPDATE | user_id = current |
| Dashboard | events | INSERT | session.user_id = current |
| Project | sessions | * | project_id = X |
| Project | tasks | * | project_id = X |
| Session detail | events | INSERT | session_id = X |
| Machines | machines | UPDATE | user_id = current |

### Subscription hook

Create a reusable React hook:

```typescript
// src/hooks/use-realtime.ts
export function useRealtime<T>(
  table: string,
  event: 'INSERT' | 'UPDATE' | 'DELETE' | '*',
  filter: string,
  callback: (payload: T) => void
) {
  useEffect(() => {
    const channel = supabase
      .channel(`${table}-${filter}`)
      .on('postgres_changes', {
        event,
        schema: 'public',
        table,
        filter,
      }, callback)
      .subscribe()

    return () => { supabase.removeChannel(channel) }
  }, [table, event, filter, callback])
}
```

## Machine online/offline indicator

### In sidebar
- Show green/gray dot next to each machine name
- Count: "2 online / 1 offline"
- Updates in realtime via subscription on `machines` table

### On machines page
- List all machines with status, last heartbeat time, active session count
- "Last seen: 2 minutes ago" for offline machines
- Meta info: OS, hostname, architecture

## Affected files

- `dispatch/supabase/functions/check-stale/index.ts` — cron Edge Function
- `dispatch/web/src/hooks/use-realtime.ts` — reusable subscription hook
- `dispatch/web/src/components/dashboard/` — update to use realtime hook
- `dispatch/web/src/components/session/` — update to use realtime hook
- `dispatch/web/src/components/sidebar.tsx` — machine online indicators
- `dispatch/web/src/app/(dashboard)/machines/page.tsx` — machines list page

## Acceptance criteria

- Stale sessions are detected within 1 minute of going silent
- Offline machines are detected within 2 minutes of missed heartbeat
- Stale sessions show warning badge in UI
- Users can manually close stale sessions
- All realtime subscriptions use the `useRealtime` hook
- Subscriptions are cleaned up on unmount (no memory leaks)
- Machine online/offline status updates in realtime in sidebar
- Machines page shows all machines with correct status and metadata

## Constraints

- Cron interval: 1 minute (not more frequent — avoid unnecessary load)
- Stale threshold: 5 minutes for sessions, 2 minutes for machines (configurable later)
- Do not send notifications for stale detection in MVP (future: Telegram bot)
- Edge Function must use service role key (cron runs without user context)
