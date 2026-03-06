---
name: cr-task-plan
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
- **Self-contained** — task description must include ALL context Claude needs. Explore the codebase yourself to find exact file paths, existing patterns, function signatures, and relevant code — then include this context directly in the task description. The more concrete details you provide upfront, the less time the executing model spends on exploration and the fewer tokens it consumes
- **Testable** — each task should leave the project in a state where tests pass
- **Sequential** — later tasks can assume earlier tasks are committed. Mention expected files/interfaces from prior tasks explicitly (e.g., "The User model in src/models/user.ts has fields id, name, email")
- **Dependency-aware** — declare dependencies explicitly via the `depends-on` frontmatter field. When generating a chain of sequential tasks, add `depends-on` to each task that relies on a prior task's output (e.g., if task `003` builds on `002`'s result, set `depends-on: 002` in task `003`). This ensures dependent tasks are automatically skipped if their prerequisite fails, rather than wasting time on doomed executions
- **Safe** — each task should specify what files to touch and what NOT to touch

## Numbering and naming

- Start numbering from the next available number (check open/, done/, failed/, and backlog/ to avoid collisions)
- Use zero-padded 3-digit prefixes: 001, 002, 003...
- Use short kebab-case slugs: `003-add-user-model.md`

## Model selection

Choose the model for each task based on its complexity:

- **haiku** — trivial tasks: create a file, rename, add a simple constant, one-line changes
- **sonnet** — standard tasks: implement a function with tests, refactor a single module, add a route with validation
- **opus** — complex tasks: architectural changes, multi-file refactoring, designing new abstractions, tasks requiring deep understanding of the codebase

Always specify the model explicitly in frontmatter. Default to `sonnet` when unsure.

## Language

Read the `language` field from the project's config file (`claude-runner.config.json` or `.claude-runner.json`). If set (e.g., `"language": "ru"`), write task titles and descriptions in that language. Code snippets, file paths, and technical terms remain in English. If no `language` field is present, write in English.

## Task file format

```markdown
---
priority: <high for foundational tasks, medium for features, low for cleanup>
model: <haiku|sonnet|opus — chosen by complexity>
depends-on: <comma-separated prefixes of prerequisite tasks, omit if none>
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
