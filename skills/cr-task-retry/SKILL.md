---
name: cr-task-retry
description: Move failed tasks back to open for another attempt by claude-runner. Use when the user wants to retry tasks that previously failed.
---

# Retry failed tasks

Move tasks from `failed/` back to `open/` for another attempt by claude-runner.

## Instructions

1. Read the project's `claude-runner.config.json` or `.claude-runner.json` to find the configured directories (`tasksDir`, `failedDir`)
2. List all `.md` files in the failed directory (default `./tasks/failed/`)
3. If there are no failed tasks, inform the user and stop
4. Show the user a list of failed tasks with their titles and ask which ones to retry:
   - "all" — move all failed tasks back to open
   - specific filenames or numbers — move only those
5. For each selected task, move it from `failed/` to `open/`
6. Optionally: ask the user if they want to edit the task description before retrying (the task may have failed because the instructions were unclear)
7. Show a summary of what was moved

## Important

- Do NOT modify the task file content unless the user explicitly asks to edit it
- If `doneStrategy` is `"status"` (not `"move"`), this skill is not applicable — inform the user
- After moving, remind the user to run `claude-runner` to execute the retried tasks

## Argument

$ARGUMENTS
