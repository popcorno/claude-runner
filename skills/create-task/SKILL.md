---
name: create-task
description: Create a new task file for claude-runner. Use when the user wants to add a task to the runner queue.
---

# Create a task for claude-runner

You are creating a task file for the claude-runner task runner.

## Instructions

1. Read the project's `claude-runner.config.json` or `.claude-runner.json` to understand the current configuration (tasksDir, doneStrategy, defaultModel, etc.)
2. Ask the user what the task should do if they haven't described it already
3. Determine the next task number by listing existing files in the tasks open directory (default `./tasks/open/`). Use zero-padded 3-digit prefix (001, 002, 003...). If the open directory has `003-xxx.md` as the highest, the next is `004`. Also check `./tasks/done/` and `./tasks/failed/` to avoid number collisions
4. Generate a short kebab-case slug from the task title (e.g., "Add user authentication" → `add-user-auth`)
5. Create the task file with this format:

```markdown
---
priority: medium
model: <default from config or user's choice>
---

# <Task title>

<Clear, detailed instructions for Claude to execute this task>

## Details

- Affected files: <list specific files if known>
- Acceptance criteria: <what defines "done">
- Constraints: <what NOT to touch, limitations>
```

## Rules

- The task description must be self-contained — Claude executing this task will have NO context from other tasks
- Be specific about file paths, function names, and expected behavior
- Include acceptance criteria so tests can verify the work
- If the user gives a vague description, ask clarifying questions before creating the file
- Do NOT include `status` field in frontmatter when using `doneStrategy: "move"` (default) — file location IS the status
- Only include `status: open` if config has `doneStrategy: "status"`
- Only include fields that differ from defaults (don't include `skip-tests: false` if that's the default)
- After creating the file, show the user the full path and a summary

## Argument

The user's task description is: $ARGUMENTS
