# Chief Wiggum

> "Bake 'em away, toys."

A vim-native command center for orchestrating autonomous Claude Code agents.

**Chief Wiggum** is a unified plugin that works as both a **Neovim plugin** AND a **Claude Code plugin** simultaneously. It enables you to dispatch verifiable tasks to Claude, track their progress through autonomous iteration, and manage multiple parallel agents from your editor.

## Philosophy

This builds on the [ralph-wiggum](https://github.com/brysontang/ralph-wiggum) autonomous loop pattern. The core insights:

1. **Verification commands are everything** - A task isn't dispatchable unless completion can be verified by a command that outputs "DONE"
2. **Failures are data** - Each iteration that doesn't complete provides directional feedback
3. **The skill shifts** - From "directing Claude step by step" to "writing prompts that converge toward correct solutions"

### Tasks That Work

- Migrations with schema validation
- Test coverage for specific functions
- Refactors with linting gates
- API implementations with contract tests
- Bug fixes with regression tests

### Tasks That Don't Work

- "Improve performance" (how much?)
- "Clean up code" (by what standard?)
- "Make it better" (better how?)
- Anything subjective or requiring human judgment

## Installation

### Neovim (lazy.nvim)

```lua
-- lua/plugins/chief-wiggum.lua
return {
  "brysontang/chief-wiggum",
  opts = {
    vault_path = "~/.chief-wiggum",  -- or "./.wiggum" for per-project
    max_agents = 5,
  },
}
```

### Neovim (packer.nvim)

```lua
use {
  "brysontang/chief-wiggum",
  config = function()
    require("chief-wiggum").setup({
      vault_path = "~/.chief-wiggum",
      max_agents = 5,
    })
  end,
}
```

### Claude Code

Add to your project's `.claude/settings.json`:

```json
{
  "permissions": {
    "allow": ["chief-wiggum:*"]
  },
  "hooks": {
    "PostToolUse": [...],
    "Stop": [...]
  }
}
```

Or install as a plugin:

```bash
claude /install brysontang/chief-wiggum
```

## Quick Start

### 1. Initialize Your Vault

```vim
:ChiefWiggumInit
```

This creates the vault directory with templates at `~/.chief-wiggum/`.

### 2. Create Your First Task

```vim
:ChiefWiggumNew rate-limiter
```

This opens a new task file from the template. Fill in:

```markdown
# Rate Limiter

## Type
mechanical

## Objective
Add IP-based rate limiting to /api/auth/* endpoints.

## Verification Command
```bash
npm test -- --grep "rate limit" && echo "DONE"
```

## Constraints
- Do not modify existing auth logic
- Use existing Redis connection
- Do not add new dependencies

## Context Files
- src/middleware/index.ts
- src/config/redis.ts

## Max Iterations
20

## Prompt
```
Implement IP-based rate limiting for authentication endpoints.

Requirements:
- 10 requests per minute per IP for /api/auth/*
- Return 429 with Retry-After header when limited
- Use Redis for distributed counting

After implementation, run:
npm test -- --grep "rate limit" && echo "DONE"

If tests pass, output: DONE
If tests fail, read the error and fix the issue.
```
```

### 3. Dispatch the Task

With your cursor in the task file:

```vim
<leader>wd
```

Or explicitly:

```vim
:ChiefWiggumDispatch ~/.chief-wiggum/tasks/features/rate-limiter.md
```

This spawns a new Claude Code session in tmux with the task context.

### 4. Monitor Progress

```vim
<leader>ws
```

Opens a floating status window showing all active agents:

```
╭─────────────────────────────────────────────────────────╮
│            CHIEF WIGGUM COMMAND CENTER                  │
│               "Bake 'em away, toys."                    │
╰─────────────────────────────────────────────────────────╯

Agents: 2 running  3 completed  1 stuck  0 waiting

─────────────────────────────────────────────────────────

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

─────────────────────────────────────────────────────────
[q] close  [r] refresh  [d] dispatch  [c] command.md
```

The trend indicators (`↑ converging`, `→ stable`, `↓ stuck/diverging`) help you see at a glance which tasks are making progress.

## Commands

### Neovim Commands

| Command | Description |
|---------|-------------|
| `:ChiefWiggumStatus` | Open status window |
| `:ChiefWiggumDispatch [file]` | Dispatch a task |
| `:ChiefWiggumRecon [dir]` | Run codebase scan |
| `:ChiefWiggumInit` | Initialize vault |
| `:ChiefWiggumNew <name>` | Create new task |

### Default Keymaps

| Keymap | Action |
|--------|--------|
| `<leader>ws` | Status window |
| `<leader>wd` | Dispatch current file |
| `<leader>wc` | Open COMMAND.md |
| `<leader>wr` | Run recon scan |
| `<leader>wq` | Open QUEUE.md |

### Claude Code Commands

| Command | Description |
|---------|-------------|
| `/chief-wiggum:dispatch <task>` | Work on a task file |
| `/chief-wiggum:status` | Show all task statuses |
| `/chief-wiggum:recon [scope]` | Scan for improvements |

## Configuration

```lua
require("chief-wiggum").setup({
  -- Where all chief-wiggum data lives
  vault_path = "~/.chief-wiggum",

  -- Command to spawn Claude (tmux, kitty, etc.)
  dispatch_cmd = "tmux new-window -n '%s' 'CHIEF_WIGGUM_TASK_ID=%s CHIEF_WIGGUM_VAULT=%s claude'",

  -- Maximum concurrent agents
  max_agents = 5,

  -- Auto-reload buffers on status change
  auto_reload = true,

  -- Show system notifications
  notify_on_complete = true,

  -- Iterations with same error before stuck
  stuck_threshold = 3,

  -- Keymaps (set to false to disable)
  keymaps = {
    status = "<leader>ws",
    dispatch = "<leader>wd",
    command = "<leader>wc",
    recon = "<leader>wr",
    queue = "<leader>wq",
  },
})
```

### Terminal Alternatives

**Kitty:**
```lua
dispatch_cmd = "kitty @ new-window --title '%s' bash -c 'CHIEF_WIGGUM_TASK_ID=%s CHIEF_WIGGUM_VAULT=%s claude'"
```

**iTerm2:**
```lua
dispatch_cmd = "osascript -e 'tell app \"iTerm\" to create window with default profile command \"CHIEF_WIGGUM_TASK_ID=%s CHIEF_WIGGUM_VAULT=%s claude\"'"
```

**Wezterm:**
```lua
dispatch_cmd = "wezterm cli spawn --new-window -- bash -c 'CHIEF_WIGGUM_TASK_ID=%s CHIEF_WIGGUM_VAULT=%s claude'"
```

## Architecture

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
│  Works autonomously using ralph-wiggum pattern:             │
│    1. Read task → 2. Implement → 3. Verify → 4. Loop       │
│                                                             │
│  Hooks fire automatically:                                  │
│    PostToolUse → Update status timestamp                   │
│    Stop        → Check for DONE, update status             │
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

## Writing Good Tasks

### The Verification Command

Every task needs a verification command that outputs `DONE` on success:

```bash
# Good: Specific and measurable
npm test -- --grep "rate limit" && echo "DONE"

# Good: Multiple checks
npm run lint && npm test && npm run build && echo "DONE"

# Bad: No completion signal
npm test

# Bad: Too broad
npm run test:all && echo "DONE"
```

### Convergent vs Divergent

**Convergent tasks** (dispatch these):
- Errors become more specific each iteration
- Fewer files changing per iteration
- Clear path to DONE

**Divergent tasks** (don't dispatch these):
- Same error 3+ times
- Scope keeps expanding
- Requires subjective judgment

### Task Types

| Type | Dispatch? | Description |
|------|-----------|-------------|
| `mechanical` | Yes | Clear verification, runs autonomously |
| `exploratory` | No | Needs human judgment mid-task |
| `architectural` | No | Needs discussion, affects many systems |

## Recon Scan

The recon command scans your codebase for actionable improvements:

```vim
:ChiefWiggumRecon src/
```

Output format:
```
- [ ] [bug:high:small] Null check missing — `src/api/users.ts:42`
- [ ] [security:high:medium] SQL injection risk — `src/db/queries.ts`
- [ ] [test:medium:small] No test for empty array — `src/utils/stats.ts`
```

Each finding can be converted into a dispatchable task.

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
| `completed` | DONE was output, verification passed |
| `stuck` | Same error 3x or max iterations reached |
| `needs_input` | Permission prompt or question |
| `pending` | Queued but not started |

## Integration with ralph-wiggum

Chief Wiggum doesn't replace [ralph-wiggum](https://github.com/brysontang/ralph-wiggum), it orchestrates it. The Stop hook uses exit code 2 to trigger ralph-style continuation.

For simpler one-off loops, use ralph-wiggum directly. Use Chief Wiggum when you need:
- Multiple parallel agents
- Persistent status tracking
- Vim-native management
- Team visibility into task progress

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

## Requirements

- Neovim 0.9+ (for `vim.uv` file watching)
- Claude Code CLI
- tmux (or alternative terminal multiplexer)
- **Optional:** `jq` for robust JSON handling in hooks (falls back to grep/sed)

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
    -- Disable some features that conflict with markdown files
    disable_frontmatter = true,
  },
}
```

This enables:
- `gf` on `[[features/rate-limiter]]` to jump to the file
- `Ctrl-o` to jump back
- `[[` completion for linking tasks
- Backlink tracking between tasks and decisions

## Contributing

Issues and PRs welcome at [github.com/brysontang/chief-wiggum](https://github.com/brysontang/chief-wiggum).

## License

MIT
