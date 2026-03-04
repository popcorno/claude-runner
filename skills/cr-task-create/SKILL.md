---
name: cr-task-create
description: Create a new task file for claude-runner. Use when the user wants to add a task to the runner queue.
---

# Create a task for claude-runner

You are creating a task file for the claude-runner task runner.

## Instructions

1. Read the project's `claude-runner.config.json` or `.claude-runner.json` to understand the current configuration (tasksDir, doneStrategy, defaultModel, etc.)
2. Ask the user what the task should do if they haven't described it already
3. Determine the next task number by listing existing files in the tasks open directory (default `./tasks/open/`). Use zero-padded 3-digit prefix (001, 002, 003...). If the open directory has `003-xxx.md` as the highest, the next is `004`. Also check `./tasks/done/`, `./tasks/failed/`, and `./tasks/backlog/` (or configured `backlogDir`) to avoid number collisions
4. Generate a short kebab-case slug from the task title (e.g., "Add user authentication" → `add-user-auth`)
5. Choose the model based on task complexity:
   - **haiku** — trivial tasks: create a file, rename, add a simple constant, one-line changes
   - **sonnet** — standard tasks: implement a function with tests, refactor a single module, add a route with validation
   - **opus** — complex tasks: architectural changes, multi-file refactoring, designing new abstractions
   Always specify the model explicitly in frontmatter. Default to `sonnet` when unsure.
6. Estimate the cost by running the `estimate-cost.sh` script bundled with this skill (in the same directory as this SKILL.md): `<skill-base-dir>/estimate-cost.sh --model <chosen-model> --done-dir <doneDir>` (use `doneDir` from config, default `./tasks/done`). If the script is not found or fails for any reason, skip this step silently — do not block task creation.
7. Check the `language` field in the config. If set (e.g., `"language": "ru"`), write the task title and description in that language. Code snippets, file paths, and technical terms remain in English.
8. Create the task file with this format:

```markdown
---
priority: medium
model: <haiku|sonnet|opus — chosen by complexity>
estimated-cost: <output of estimate-cost.sh, omit if script unavailable>
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
- Be specific about file paths, function names, and expected behavior. Explore the codebase yourself to find exact paths, existing patterns, and relevant code — then include this context in the task description. The more concrete details you provide upfront, the less time the executing model spends on exploration and the fewer tokens it consumes
- Include acceptance criteria so tests can verify the work
- If the user gives a vague description or just an idea (not a concrete task), suggest creating it in the backlog directory (`backlogDir` from config, default `./tasks/backlog/`) instead of open. The backlog is for ideas and drafts that are not ready to be executed. Ask the user to confirm
- Do NOT include `status` field in frontmatter when using `doneStrategy: "move"` (default) — file location IS the status
- Only include `status: open` if config has `doneStrategy: "status"`
- Only include fields that differ from defaults (don't include `skip-tests: false` if that's the default)
- After creating the file, show the user the full path and a summary

## Argument

The user's task description is: $ARGUMENTS
