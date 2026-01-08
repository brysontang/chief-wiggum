# Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        DEVELOPER                            │
│                                                             │
│  vim COMMAND.md                                             │
│    │                                                        │
│    ├── <leader>wr  →  Recon scan                           │
│    │                   └── Updates tasks/RECON.md           │
│    │                                                        │
│    ├── Edit feature file                                    │
│    │    └── Write verification command                      │
│    │                                                        │
│    └── <leader>wd  →  Dispatch                             │
│                        └── Spawns Claude in tmux            │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      CLAUDE CODE                            │
│                                                             │
│  Works autonomously using the ralph-wiggum pattern:         │
│    1. Read task → 2. Implement → 3. Verify → 4. Loop       │
│                                                             │
│  Hooks fire automatically:                                  │
│    PostToolUse → Update status timestamp                   │
│    Stop        → Check for completion marker               │
│                  Exit 2 to continue if not done            │
│    Notification → Alert on permission prompts              │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                 ~/.chief-wiggum/status/                     │
│                                                             │
│  rate-limiter.json                                          │
│  {                                                          │
│    "task": "rate-limiter",                                  │
│    "status": "running",                                     │
│    "iteration": 4,                                          │
│    "iterations_history": [...]                              │
│  }                                                          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   NEOVIM (watching)                         │
│                                                             │
│  vim.uv file watcher sees status change                    │
│    └── Triggers checktime                                   │
│        └── Status window updates                            │
│        └── System notification on complete/stuck            │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## The Ralph-Wiggum Pattern

Chief Wiggum implements the [ralph-wiggum pattern](https://paddo.dev/blog/ralph-wiggum-autonomous-loops/) for autonomous iteration. The Stop hook uses exit code 2 to trigger continuation until the agent outputs `###CHIEF_WIGGUM_DONE###` (a unique marker to avoid false positives).

## Status Window

```
╭─────────────────────────────────────────────────────────────╮
│            CHIEF WIGGUM COMMAND CENTER                      │
│               "Bake 'em away, toys."                        │
╰─────────────────────────────────────────────────────────────╯

Agents: 2 running  3 completed  1 stuck  0 waiting

─────────────────────────────────────────────────────────────

● rate-limiter
  iter 4/20 • 12m • ↑ converging
  └─ Last: test timeout on slow network

● db-migration
  iter 2/20 • 3m
  └─ Last: missing column in schema

✓ auth-refactor
  completed in 8 iterations

✗ api-optimization
  stuck at iter 15 • ↓ stuck
  └─ Same error 3x: circular dependency

─────────────────────────────────────────────────────────────
[q] close  [r] refresh  [d] dispatch  [c] command.md
```

The trend indicators (`↑ converging`, `→ stable`, `↓ stuck/diverging`) help you see at a glance which tasks are making progress.
