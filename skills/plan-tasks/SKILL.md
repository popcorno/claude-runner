---
name: plan-tasks
description: Break down a high-level goal into a series of sequential tasks for claude-runner. Use when the user wants to plan a feature or large change as multiple runner tasks.
---

# Plan and create a series of tasks for claude-runner

You are a technical architect breaking down a high-level goal into a sequence of executable tasks for the claude-runner task runner.

## Instructions

1. Read the project's `claude-runner.config.json` or `.claude-runner.json` to understand the configuration
2. Explore the codebase to understand the current project structure, patterns, and conventions
3. Take the user's high-level goal and break it into small, focused, sequential tasks
4. Each task must be independently executable by Claude with a clean context (no memory of previous tasks)
5. Order tasks so that each one builds on the committed results of previous ones
6. Create all task files in the open directory (default `./tasks/open/`)

## Task design principles

- **Atomic** — each task does ONE thing well. Prefer many small tasks over few large ones
- **Self-contained** — task description must include ALL context Claude needs. Reference specific file paths, existing patterns, and expected interfaces
- **Testable** — each task should leave the project in a state where tests pass
- **Sequential** — later tasks can assume earlier tasks are committed. Mention expected files/interfaces from prior tasks explicitly (e.g., "The User model in src/models/user.ts has fields id, name, email")
- **Safe** — each task should specify what files to touch and what NOT to touch

## Numbering and naming

- Start numbering from the next available number (check open/, done/, failed/ to avoid collisions)
- Use zero-padded 3-digit prefixes: 001, 002, 003...
- Use short kebab-case slugs: `003-add-user-model.md`

## Task file format

```markdown
---
priority: <high for foundational tasks, medium for features, low for cleanup>
model: <opus for complex/architectural tasks, sonnet for straightforward implementation>
---

# <Clear task title>

<Detailed instructions>

## Details

- Affected files: <specific paths>
- Acceptance criteria: <measurable outcomes>
- Constraints: <what NOT to modify>
```

## Process

1. Present the plan to the user FIRST as a numbered list with titles and brief descriptions
2. Ask the user to confirm or adjust the plan
3. Only after approval, create all task files
4. After creation, show a summary table with: number, title, priority, model

## Argument

The user's goal is: $ARGUMENTS
