# Multi-Tool Agents

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

## The Council Pattern

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

## Creating Custom Agents

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
