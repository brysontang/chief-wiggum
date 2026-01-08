# Chief Wiggum

> "Bake 'em away, toys."

**This is experimental software in active development. Read the code before using. Things will break.**

A composable framework for orchestrating autonomous Claude Code agents.

## What is this?

Chief Wiggum is an **orchestration layer** for Claude Code agents. You define workflows as markdown, wire stages to agents, and let Claude do the work.

```markdown
### RESEARCH ← ACTIVE
Agent: chief-wiggum:recon

### IMPLEMENT
Agent: chief-wiggum:implement
Verification: `npm test`

### SECURITY
Agent: acme-corp:security-scan    # Your custom agent
```

**Key ideas:**
- **Tasks are markdown** - Human-readable, editable, version-controlled
- **Agents are pluggable** - Use any Claude Code agent from any plugin
- **Templates are per-project** - Different workflows for different project types
- **Everything is customizable** - Swap agents, change stages, edit mid-flight

## Installation

### As a Claude Code Plugin

```bash
/plugin marketplace add brysontang/chief-wiggum
/plugin install chief-wiggum@brysontang-chief-wiggum
```

### As a Neovim Plugin (lazy.nvim)

```lua
return {
  "brysontang/chief-wiggum",
  opts = {
    vault_path = "./.wiggum",  -- Per-project config
  },
}
```

## Quick Start

```vim
:ChiefWiggumInit          " Initialize .wiggum directory
:ChiefWiggumNew my-task   " Create task from template
<leader>wd                " Dispatch to Claude
<leader>ws                " Monitor status
```

## How It Works

1. **Create a task** from a template (or write your own markdown)
2. **Dispatch** sends the current stage to its agent
3. **Agent works** autonomously until verification passes (or gets stuck)
4. **Stage advances** automatically on completion
5. **You control** when to dispatch the next stage

```
Task File          →  Dispatch  →  Claude Code  →  Stage Complete
(markdown)            (Neovim)     (agent runs)    (marker advances)
```

## The Power: Composability

### Custom Agents

Use any agent from any Claude Code plugin:

```markdown
Agent: chief-wiggum:implement     # Built-in
Agent: my-team:security-review    # Team plugin
Agent: my-plugin:custom-agent     # Your own
Agent: human                      # Manual checkpoint
```

### Custom Templates

Different workflows for different task types:

```
.wiggum/templates/
├── feature.md      # Full pipeline (RESEARCH → PLAN → IMPLEMENT → TEST → REVIEW → MERGE)
├── bugfix.md       # Lighter pipeline (IMPLEMENT → TEST → REVIEW)
├── hotfix.md       # Minimal (IMPLEMENT → REVIEW)
└── docs.md         # Documentation only
```

### Project-Specific Verification

Templates define verification commands for your stack:

```markdown
# Python project template
Verification: `pytest tests/ -v`

# Go project template
Verification: `go test ./...`

# Node project template
Verification: `npm test`
```

## Commands

| Command | Keymap | Description |
|---------|--------|-------------|
| `:ChiefWiggumStatus` | `<leader>ws` | Open status window |
| `:ChiefWiggumDispatch` | `<leader>wd` | Dispatch current task |
| `:ChiefWiggumNew <name>` | — | Create new task |
| `:ChiefWiggumAdvance` | `<leader>wn` | Advance to next stage |
| `:ChiefWiggumRegress` | `<leader>wp` | Go to previous stage |

## Philosophy

Inspired by [ralph-wiggum](https://paddo.dev/blog/ralph-wiggum-autonomous-loops/):

1. **Verification commands are everything** - Tasks need a command that succeeds (exit 0)
2. **Failures are data** - Each iteration provides feedback
3. **State lives in files** - Every dispatch is fresh; the filesystem is memory
4. **Orchestration, not ownership** - Chief Wiggum wires agents together; it doesn't own them

## Requirements

- Neovim 0.9+
- Claude Code CLI
- tmux

## Documentation

- [Philosophy](docs/philosophy.md) - Why fresh contexts matter
- [Stages](docs/stages.md) - Pipeline stages and custom workflows
- [Agents](docs/agents.md) - Using and creating agents
- [Worktrees](docs/worktrees.md) - Git worktree isolation
- [Writing Tasks](docs/writing-tasks.md) - How to write good tasks
- [Architecture](docs/architecture.md) - How it works
- [Configuration](docs/configuration.md) - Full config options
- [Reference](docs/reference.md) - Status files, vault structure

## Contributing

Issues and PRs welcome at [github.com/brysontang/chief-wiggum](https://github.com/brysontang/chief-wiggum).

## License

MIT
