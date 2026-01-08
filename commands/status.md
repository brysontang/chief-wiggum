---
name: status
description: Show the current status of all chief-wiggum tasks
arguments: []
---

# Chief Wiggum Status

Display the current status of all dispatched tasks.

## Instructions

1. Read all `.json` files in `$CHIEF_WIGGUM_VAULT/status/` (default: `~/.chief-wiggum/status/`)
2. Parse each status file and display a summary

## Output Format

```
╭─────────────────────────────────────────────────────────╮
│            CHIEF WIGGUM COMMAND CENTER                  │
│               "Bake 'em away, toys."                    │
╰─────────────────────────────────────────────────────────╯

Agents: X running  Y completed  Z stuck  W waiting

─────────────────────────────────────────────────────────

● task-name-1
  iter 4/20 • 5m
  └─ Last: type error in auth.ts

✓ task-name-2
  completed in 12 iterations

✗ task-name-3
  stuck at iter 8
  └─ Same error 3x: missing dependency

? task-name-4
  waiting for input
  └─ Need clarification on API schema

─────────────────────────────────────────────────────────
```

## Status Icons

- `●` running - Task is actively being worked on
- `✓` completed - Task finished successfully (DONE was output)
- `✗` stuck - Task encountered repeated failures
- `?` needs_input - Task requires human intervention
- `○` pending - Task is queued but not started

## Reading Status Files

Each status file has this structure:

```json
{
  "task": "task-id",
  "name": "Human readable name",
  "status": "running|completed|stuck|needs_input",
  "iteration": 4,
  "max_iterations": 20,
  "iterations_history": [
    {"iter": 1, "outcome": "description of what happened"}
  ],
  "started_at": "2026-01-08T10:00:00Z",
  "last_update": "2026-01-08T10:42:00Z"
}
```

Now read the status directory and display the current state.
