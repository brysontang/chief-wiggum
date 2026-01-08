# Git Worktrees

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

## Commands

| Command | Description |
|---------|-------------|
| `:ChiefWiggumWorktrees` | List all task worktrees |
| `:ChiefWiggumPrune` | Remove orphaned worktrees |

## How It Works

1. **First dispatch** creates a worktree at `.worktrees/<task-id>`
2. **Agent runs** in the worktree, isolated from main branch
3. **Changes stay isolated** until MERGE stage
4. **Merge agent** handles rebase and conflict resolution

## Benefits

- **No branch switching** - Work on multiple tasks simultaneously
- **Clean main branch** - WIP code never touches main
- **Easy cleanup** - Delete worktree, no trace left
- **Parallel agents** - Multiple agents can work without conflicts

## Staleness Detection

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

## Configuration

```lua
require("chief-wiggum").setup({
  worktree_base = ".worktrees",   -- Relative to project root
  auto_create_worktree = true,    -- Create worktree on first dispatch
})
```
