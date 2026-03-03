---
name: promote
description: Move backlog tasks to open for execution by claude-runner. Use when the user wants to promote ideas/drafts into ready-to-run tasks.
---

# Promote backlog tasks

Move tasks from the backlog directory to the open directory so they can be executed by claude-runner.

## Instructions

1. Read the project's `claude-runner.config.json` or `.claude-runner.json` to find the configured directories (`tasksDir`, `backlogDir`)
2. List all `.md` files in the backlog directory (default `./tasks/backlog/`)
3. If there are no backlog tasks, inform the user and stop
4. Show the user a list of backlog tasks with their titles and ask which ones to promote:
   - "all" — move all backlog tasks to open
   - specific filenames or numbers — move only those
5. For each selected task:
   - Ask the user if they want to review or refine the task description before promoting (the task may be a rough idea that needs fleshing out)
   - Move the file from backlog to open
6. Show a summary of what was moved

## Important

- If a task description is vague or incomplete, help the user flesh it out before moving — add specific file paths, acceptance criteria, and constraints
- Do NOT modify the task file unless the user explicitly asks to edit it or agrees to refinement
- After moving, remind the user to run `claude-runner` to execute the promoted tasks
- Check for number collisions with existing tasks in open/, done/, and failed/ — rename if needed

## Argument

$ARGUMENTS
