# Chief Wiggum

> "Bake 'em away, toys."

A vim-native command center for orchestrating autonomous Claude Code agents.

**Chief Wiggum** works as both a **Neovim plugin** and a **Claude Code plugin**. Dispatch verifiable tasks to Claude, track progress through autonomous iteration, and manage multiple parallel agents from your editor.

## Philosophy

Inspired by [ralph-wiggum](https://paddo.dev/blog/ralph-wiggum-autonomous-loops/):

1. **Verification commands are everything** - Tasks need a command that outputs "DONE"
2. **Failures are data** - Each iteration provides feedback
3. **State lives in files** - Every dispatch is fresh; the filesystem is memory

## Installation

### Neovim (lazy.nvim)

```lua
return {
  "brysontang/chief-wiggum",
  opts = {
    vault_path = "~/.chief-wiggum",  -- or "./.wiggum" for per-project
    max_agents = 5,
  },
}
```

### Claude Code

```bash
/plugin marketplace add brysontang/chief-wiggum
/plugin install chief-wiggum@brysontang-chief-wiggum
```

## Quick Start

```vim
:ChiefWiggumInit          " Initialize vault
:ChiefWiggumNew my-task   " Create task from template
<leader>wd                " Dispatch to Claude
<leader>ws                " Monitor status
```

## Commands

| Command | Keymap | Description |
|---------|--------|-------------|
| `:ChiefWiggumStatus` | `<leader>ws` | Open status window |
| `:ChiefWiggumDispatch` | `<leader>wd` | Dispatch current task |
| `:ChiefWiggumNew <name>` | — | Create new task |
| `:ChiefWiggumAdvance` | `<leader>wn` | Next stage |
| `:ChiefWiggumRegress` | `<leader>wp` | Previous stage |
| `:ChiefWiggumRecon` | `<leader>wr` | Scan for improvements |

## Requirements

- Neovim 0.9+
- Claude Code CLI
- tmux

## Documentation

- [Philosophy](docs/philosophy.md) - Why fresh contexts matter
- [Stages](docs/stages.md) - Pipeline stages and navigation
- [Agents](docs/agents.md) - Multi-tool and custom agents
- [Worktrees](docs/worktrees.md) - Git worktree isolation
- [Configuration](docs/configuration.md) - Full config options
- [Writing Tasks](docs/writing-tasks.md) - How to write good tasks
- [Architecture](docs/architecture.md) - How it works
- [Reference](docs/reference.md) - Status files, vault structure, skills

## Contributing

Issues and PRs welcome at [github.com/brysontang/chief-wiggum](https://github.com/brysontang/chief-wiggum).

## License

MIT
