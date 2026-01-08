# Chief Wiggum

> "Bake 'em away, toys."

A vim-native command center for orchestrating autonomous Claude Code agents.

**Chief Wiggum** is a unified plugin that works as both a **Neovim plugin** AND a **Claude Code plugin** simultaneously. It enables you to dispatch verifiable tasks to Claude, track their progress through autonomous iteration, and manage multiple parallel agents from your editor.

## Philosophy

This builds on the [ralph-wiggum](https://paddo.dev/blog/ralph-wiggum-autonomous-loops/) autonomous loop pattern. The core insights:

1. **Verification commands are everything** - A task isn't dispatchable unless completion can be verified by a command that outputs "DONE"
2. **Failures are data** - Each iteration that doesn't complete provides directional feedback
3. **The skill shifts** - From "directing Claude step by step" to "writing prompts that converge toward correct solutions"
4. **State lives in files, not context** - Every dispatch is fresh; the filesystem is the memory

### Why Fresh Contexts

Chief Wiggum dispatches agents with **fresh context windows every time**. This is intentional:

```
Traditional approach:
┌─────────────────────────────────────────┐
│ Context Window                          │
│ ┌─────────────────────────────────────┐ │
│ │ iter 1: tried X, failed            │ │
│ │ iter 2: tried Y, failed            │ │
│ │ iter 3: tried Z, failed            │ │
│ │ iter 4: tried X again (forgot!)    │ │  ← Context pollution
│ │ iter 5: confused by old context    │ │
│ │ ...                                 │ │
│ │ iter N: context full, degraded     │ │
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘

Chief Wiggum approach:
┌─────────────┐   ┌─────────────┐   ┌─────────────┐
│ Fresh       │   │ Fresh       │   │ Fresh       │
│ Context     │   │ Context     │   │ Context     │
│             │   │             │   │             │
│ Read task → │   │ Read task → │   │ Read task → │
│ See log     │   │ See log     │   │ See log     │
│ Know state  │   │ Know state  │   │ Know state  │
└─────────────┘   └─────────────┘   └─────────────┘
      ↓                 ↓                 ↓
   task.md           task.md           task.md
   (updated)         (updated)         (updated)
```

**The agent doesn't remember. The files remember.**

Each dispatch reads:
- **The task file** - Objective, constraints, verification command
- **The ## Log section** - What previous iterations accomplished
- **MODULE.md files** - Patterns in the code
- **Git history** - What changed recently
- **The code itself** - Current state on disk

This eliminates context pollution and gives each iteration the agent's full attention.

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

Opens a floating status window showing all active agents.

## Stage Pipelines

Tasks flow through stages, each with its own agent:

```markdown
## Stages

### RESEARCH <- ACTIVE
Agent: recon
- [ ] Identify files that handle rate limiting
- [ ] Check existing middleware patterns

### PLAN
Agent: human
- [ ] Decide on rate limiting algorithm
- [ ] Choose storage backend

### IMPLEMENT
Agent: implement
Verification: `npm test -- --grep "rate limit" && echo DONE`

### TEST
Agent: test
Verification: `npm run test:coverage -- --threshold 80 && echo DONE`

### REVIEW
Agent: review

### MERGE
Agent: merge
```

### Stage Navigation

| Keymap | Action |
|--------|--------|
| `<leader>wn` | Advance to next stage |
| `<leader>wp` | Regress to previous stage |
| `<CR>` | Toggle checkbox item |
| `<leader>wd` | Dispatch current stage |

The `<- ACTIVE` marker shows which stage is current. Dispatching runs the agent for that stage with the stage's verification command.

### Default Stage Agents

| Stage | Agent | Purpose |
|-------|-------|---------|
| RESEARCH | recon | Scan codebase, identify patterns |
| PLAN | human | Requires human decision-making |
| IMPLEMENT | implement | Write the code |
| TEST | test | Add test coverage |
| REVIEW | review | Check for bugs, security, patterns |
| MERGE | merge | Rebase and prepare for merge |

## Multi-Tool Agents

**Agent = Tool + Model + Prompt**

Different AI tools have different training data, latent spaces, and personalities. Chief Wiggum lets you assign different tools to different stages:

```lua
require("chief-wiggum").setup({
  -- Override which tool an agent uses
  agent_tool = {
    implement = "claude",
    review = "codex",    -- Different model catches different bugs
    test = "aider",
  },

  -- Commands for each tool
  dispatch_commands = {
    claude = "tmux new-window -n '%s' 'cd %s && claude'",
    codex = "tmux new-window -n '%s' 'cd %s && codex --task-file %s'",
    aider = "tmux new-window -n '%s' 'cd %s && aider --message-file %s'",
    ollama = "tmux new-window -n '%s' 'cd %s && ollama run %s < %s'",
  },
})
```

### The Council Pattern

Use multiple models as checks and balances:

```
Claude (implements)     Codex (reviews)
        ↘                   ↙
          [same code]
        ↙                   ↘
Different priors     Different blind spots
```

**Why this matters:**
- Models trained on different data see different patterns
- A bug obvious to one model may be invisible to another
- Review by a different model catches implementation blind spots

### Creating Custom Agents

Agents live in your vault's `agents/` directory:

```markdown
---
name: security-review
tool: claude
description: Security-focused code review
tools:
  - Read
  - Glob
  - Grep
---

# Security Review Agent

You review code for security vulnerabilities.

## Checklist
- [ ] Input validation
- [ ] SQL injection
- [ ] XSS
- [ ] Authentication bypass
...
```

The `tool` field in frontmatter specifies which AI tool runs this agent.

## Git Worktrees

Each task gets an isolated git worktree, preventing work from colliding:

```
project/
├── .git/
├── src/
└── .worktrees/
    ├── rate-limiter/      # Task: rate-limiter
    │   ├── src/
    │   └── ...
    └── db-migration/      # Task: db-migration
        ├── src/
        └── ...
```

### Worktree Commands

| Command | Description |
|---------|-------------|
| `:ChiefWiggumWorktrees` | List all task worktrees |
| `:ChiefWiggumPrune` | Remove orphaned worktrees |

### How It Works

1. **First dispatch** creates a worktree at `.worktrees/<task-id>`
2. **Agent runs** in the worktree, isolated from main branch
3. **Changes stay isolated** until MERGE stage
4. **Merge agent** handles rebase and conflict resolution

### Worktree Benefits

- **No branch switching** - Work on multiple tasks simultaneously
- **Clean main branch** - WIP code never touches main
- **Easy cleanup** - Delete worktree, no trace left
- **Parallel agents** - Multiple agents can work without conflicts

### Staleness Detection

```vim
:ChiefWiggumWorktrees
```

Shows how far behind main each worktree is:

```
╭─ Worktrees ─────────────────────────────────────╮
│ rate-limiter    5 commits behind  [dirty]      │
│ db-migration    0 commits behind  [clean]      │
│ auth-refactor   12 commits behind [clean]      │
╰─────────────────────────────────────────────────╯
```

## Status Window

Opening the status window:

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
| `:ChiefWiggumAdvance` | Advance to next stage |
| `:ChiefWiggumRegress` | Go back to previous stage |
| `:ChiefWiggumWorktrees` | List all task worktrees |
| `:ChiefWiggumPrune` | Remove orphaned worktrees |

### Default Keymaps

| Keymap | Action |
|--------|--------|
| `<leader>ws` | Status window |
| `<leader>wd` | Dispatch current file/stage |
| `<leader>wc` | Open COMMAND.md |
| `<leader>wr` | Run recon scan |
| `<leader>wq` | Open QUEUE.md |
| `<leader>wn` | Advance to next stage |
| `<leader>wp` | Regress to previous stage |

### Task File Keymaps

When editing a task file with stages:

| Keymap | Action |
|--------|--------|
| `<CR>` | Toggle checkbox item |

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

  -- Maximum concurrent agents
  max_agents = 5,

  -- Auto-reload buffers on status change
  auto_reload = true,

  -- Show system notifications
  notify_on_complete = true,

  -- Iterations with same error before stuck
  stuck_threshold = 3,

  -- Git worktree settings
  worktree = {
    enabled = true,
    base_dir = ".worktrees",  -- Relative to project root
    auto_create = true,       -- Create worktree on first dispatch
    auto_cleanup = false,     -- Remove worktree after merge
  },

  -- Stage pipeline settings
  stages = {
    enabled = true,
    auto_advance = false,     -- Auto-advance stage on DONE
    default_stages = { "RESEARCH", "PLAN", "IMPLEMENT", "TEST", "REVIEW", "MERGE" },
  },

  -- Default agent for each stage
  agent_for_stage = {
    RESEARCH = "recon",
    PLAN = "human",         -- "human" means don't dispatch, requires manual work
    IMPLEMENT = "implement",
    TEST = "test",
    REVIEW = "review",
    MERGE = "merge",
  },

  -- Override which tool an agent uses (optional)
  agent_tool = {
    -- implement = "claude",
    -- review = "codex",
  },

  -- Commands for each AI tool
  dispatch_commands = {
    claude = "tmux new-window -n '%s' 'cd %s && CHIEF_WIGGUM_TASK_ID=%s CHIEF_WIGGUM_VAULT=%s claude'",
    codex = "tmux new-window -n '%s' 'cd %s && CHIEF_WIGGUM_TASK_ID=%s codex --task-file %s'",
    aider = "tmux new-window -n '%s' 'cd %s && CHIEF_WIGGUM_TASK_ID=%s aider --message-file %s'",
    ollama = "tmux new-window -n '%s' 'cd %s && CHIEF_WIGGUM_TASK_ID=%s ollama run %s < %s'",
  },

  -- Keymaps (set to false to disable)
  keymaps = {
    status = "<leader>ws",
    dispatch = "<leader>wd",
    command = "<leader>wc",
    recon = "<leader>wr",
    queue = "<leader>wq",
    advance = "<leader>wn",
    regress = "<leader>wp",
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

Chief Wiggum doesn't replace [ralph-wiggum](https://paddo.dev/blog/ralph-wiggum-autonomous-loops/), it orchestrates it. The Stop hook uses exit code 2 to trigger ralph-style continuation.

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
