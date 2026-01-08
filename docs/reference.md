# Reference

## Status File Format

```json
{
  "task": "rate-limiter",
  "name": "Rate Limiter",
  "path": "/path/to/task.md",
  "status": "running",
  "iteration": 4,
  "max_iterations": 20,
  "iterations_history": [
    {"iter": 1, "outcome": "missing import"},
    {"iter": 2, "outcome": "type error"},
    {"iter": 3, "outcome": "test timeout"},
    {"iter": 4, "outcome": "running..."}
  ],
  "started_at": "2026-01-08T10:00:00Z",
  "last_update": "2026-01-08T10:42:00Z"
}
```

### Status Values

| Status | Meaning |
|--------|---------|
| `running` | Agent is actively working |
| `completed` | Completion marker output, verification passed |
| `stuck` | Same error 3x or max iterations reached |
| `needs_input` | Permission prompt or question |
| `pending` | Queued but not started |

## Vault Structure

```
~/.chief-wiggum/
├── COMMAND.md           # Your command center view
├── QUEUE.md             # Task queue
├── tasks/
│   ├── features/        # Task files
│   │   ├── rate-limiter.md
│   │   └── db-migration.md
│   └── RECON.md         # Latest recon findings
├── agents/              # Custom agent definitions
│   ├── implement.md
│   ├── test.md
│   ├── review.md
│   ├── merge.md
│   ├── recon.md
│   └── security-review.md  # Your custom agents
├── decisions/           # Architectural Decision Records (ADRs)
│   └── 2026-01-auth-pattern.md
├── status/              # JSON status files (auto-managed)
│   ├── rate-limiter.json
│   └── db-migration.json
├── logs/                # Historical logs
├── prompts/             # Extracted prompts for dispatch
└── templates/           # Your customized templates
    ├── feature.md
    └── decision.md

project/                 # Your project (when using worktrees)
├── .git/
├── src/
└── .worktrees/          # Task worktrees (gitignored)
    ├── rate-limiter/
    └── db-migration/
```

## Skills

Chief Wiggum includes skills that teach Claude better patterns:

### task-convergence

How to write tasks that converge toward completion. Covers:
- Writing effective verification commands
- Recognizing convergent vs divergent patterns
- When NOT to dispatch (subjective tasks)

### context-sync

Protocol for reading context before modifying code. Prevents Claude from:
- Missing existing patterns
- Introducing inconsistencies
- Ignoring documented gotchas

The context-sync skill encourages maintaining `MODULE.md` or `CONTEXT.md` files alongside complex modules.

## Wiki Navigation (Optional)

Chief Wiggum works great with [obsidian.nvim](https://github.com/obsidian-nvim/obsidian.nvim) for `[[wiki-style]]` navigation:

```lua
-- lua/plugins/obsidian.lua
return {
  "obsidian-nvim/obsidian.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  opts = {
    workspaces = {
      { name = "wiggum", path = "~/.chief-wiggum" },
    },
    disable_frontmatter = true,
  },
}
```

This enables:
- `gf` on `[[features/rate-limiter]]` to jump to the file
- `Ctrl-o` to jump back
- `[[` completion for linking tasks
- Backlink tracking between tasks and decisions
