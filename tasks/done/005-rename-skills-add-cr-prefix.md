---
priority: medium
model: sonnet
---

# Rename skills to `cr-task-*` namespace

All skills in the `skills/` directory need a `cr-task-` namespace prefix to avoid name collisions with user-defined skills and to group them together in autocomplete.

## Current → Target mapping

| Current directory | New directory |
|---|---|
| `skills/create-task/` | `skills/cr-task-create/` |
| `skills/plan-tasks/` | `skills/cr-task-plan/` |
| `skills/promote/` | `skills/cr-task-promote/` |
| `skills/retry-failed/` | `skills/cr-task-retry/` |

## Steps

1. **Rename directories** in `skills/`:
   - `mv skills/create-task skills/cr-task-create`
   - `mv skills/plan-tasks skills/cr-task-plan`
   - `mv skills/promote skills/cr-task-promote`
   - `mv skills/retry-failed skills/cr-task-retry`

2. **Update `name` field** in each `SKILL.md` frontmatter:
   - `name: create-task` → `name: cr-task-create`
   - `name: plan-tasks` → `name: cr-task-plan`
   - `name: promote` → `name: cr-task-promote`
   - `name: retry-failed` → `name: cr-task-retry`

3. **Update references in `CLAUDE.md`** — the Skills section lists available commands as `/create-task`, `/plan-tasks`, `/promote`, `/retry-failed`. Update to `/cr-task-create`, `/cr-task-plan`, `/cr-task-promote`, `/cr-task-retry`.

4. **Update references in `README.md`** — search for all mentions of skill names and update them with the new names.

5. **Search the entire repo** for any other references to the old skill names (e.g., in examples, comments, or config files) and update them.

## Acceptance criteria

- All skill directories follow the `cr-task-*` naming pattern
- All `SKILL.md` files have the correct `name` field matching the new names
- No references to old unprefixed skill names remain in the repo (CLAUDE.md, README.md, or anywhere else)
- Existing tests still pass (`npm test`)

## Constraints

- Do not modify skill logic or behavior — only rename
- Do not change the internal content/instructions of SKILL.md files beyond the `name` field
