---
priority: medium
model: opus
estimated-cost: 3.0000
depends-on: 016
---

# Dispatch: Task manager UI and night scheduler

Build the task creation form, task management interface, and scheduled task functionality. This enables creating and managing tasks from the web UI and scheduling overnight batch runs.

## Task creation form

Available from the project page ("+ New Task" button) and the schedule page.

### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| Title | text | yes | Short task name |
| Prompt | textarea | yes | Full prompt for `claude -p` |
| Project | select | yes | Which project (pre-filled if opened from project page) |
| Machine | select | no | Target machine (null = any available) |
| Priority | number | no | Higher = more important (default: 0) |
| Model | select | no | claude-sonnet-4, claude-opus-4 (default: project default or sonnet) |
| Max turns | number | no | Max conversation turns (default: 50) |
| Scheduled at | datetime | no | When to run (null = as soon as possible) |
| Dependencies | multi-select | no | Other tasks that must complete first |

### Prompt editor

- Monospace textarea with decent height
- Markdown preview toggle
- Template snippets (optional, future): "Add tests for...", "Refactor...", "Fix bug..."

## Task list / management

### On project page (Tasks tab)

Kanban-style columns showing tasks for the project:

- **Queued**: tasks waiting to run, ordered by priority
- **Running**: currently executing (show progress: machine, duration)
- **Done**: completed tasks (collapsible, show result_summary)
- **Error**: failed tasks (show error_message, "Retry" button)

Actions per task:
- **View**: expand to see full prompt, result, timing
- **Cancel**: change status to 'cancelled' (only for queued tasks)
- **Retry**: create a new task with same prompt (for failed tasks)
- **Delete**: remove task (only for queued/cancelled tasks)

### On machines page

Show tasks currently running on each machine and queued tasks assigned to it.

## Schedule page (`/schedule`)

### Night batch creation

Interface for planning a batch of tasks to run overnight:

1. Select project
2. Add multiple tasks (title + prompt for each)
3. Set execution order (drag to reorder → sets priority)
4. Set dependencies between tasks (checkboxes: "Task 3 depends on Task 1 and 2")
5. Set scheduled time (e.g., "Tonight at 23:00")
6. Select target machine (or "any available")
7. "Schedule batch" button → creates all tasks with correct `priority`, `depends_on`, and `scheduled_at`

### Scheduled tasks view

- Calendar/timeline view of upcoming scheduled tasks
- Group by date
- Show: time, project, task title, target machine
- Cancel/edit before execution time

### Recurring tasks (stretch goal)

- Option to make a task recurring (daily, weekly)
- Stored as a `recurring_tasks` config (or separate table — keep simple for MVP)
- For MVP: just a note in the UI "For recurring tasks, re-schedule manually"

## Implementation details

### Task creation

```typescript
const createTask = async (data: TaskFormData) => {
  const { error } = await supabase
    .from('tasks')
    .insert({
      user_id: user.id,
      project_id: data.projectId,
      machine_id: data.machineId || null,
      title: data.title,
      prompt: data.prompt,
      priority: data.priority || 0,
      depends_on: data.dependsOn || [],
      max_turns: data.maxTurns || 50,
      scheduled_at: data.scheduledAt || null,
    })

  // Supabase Realtime will notify the dashboard
}
```

### Task cancellation

```typescript
const cancelTask = async (taskId: string) => {
  await supabase
    .from('tasks')
    .update({ status: 'cancelled' })
    .eq('id', taskId)
    .eq('status', 'queued')  // only cancel if still queued
}
```

### Batch creation

```typescript
const createBatch = async (batch: BatchData) => {
  const tasks = batch.tasks.map((task, index) => ({
    ...task,
    priority: batch.tasks.length - index,  // first task = highest priority
    scheduled_at: batch.scheduledAt,
    depends_on: task.dependsOn,
  }))

  await supabase.from('tasks').insert(tasks)
}
```

## Affected files

- `dispatch/web/src/app/(dashboard)/projects/[slug]/tasks/page.tsx` — full task list for project
- `dispatch/web/src/app/(dashboard)/schedule/page.tsx` — scheduler page
- `dispatch/web/src/components/tasks/` — task-form, task-card, task-kanban, batch-creator
- `dispatch/web/src/components/schedule/` — schedule-timeline, batch-form

## Acceptance criteria

- Tasks can be created from the web UI with all required fields
- Task list shows tasks grouped by status (kanban columns)
- Queued tasks can be cancelled
- Failed tasks can be retried (creates new task with same prompt)
- Schedule page allows creating batches with ordered tasks and dependencies
- `scheduled_at` is respected (tasks don't run before scheduled time)
- Dependencies are correctly set via UI (multi-select from existing project tasks)
- Realtime updates: new/changed tasks appear without refresh
- Form validation: title and prompt are required
- Empty states are handled

## Constraints

- No drag-and-drop for kanban in MVP (just visual columns)
- Drag-to-reorder for batch creation is a nice-to-have (can use up/down buttons instead)
- Recurring tasks are out of scope for MVP — just document it as future work
- Keep forms simple — no rich text editor for prompts, just textarea
