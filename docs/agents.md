# Agents

**Agent = Plugin + Instructions + Tools**

Chief Wiggum orchestrates Claude Code agents. Any agent from any plugin can be used in your task pipelines.

## Agent Format

Agents are referenced by their full name: `plugin:agent-name`

```markdown
### IMPLEMENT
Agent: chief-wiggum:implement    # Built-in agent

### SECURITY
Agent: acme-corp:security-scan   # Your team's custom agent

### PLAN
Agent: human                     # Manual checkpoint (no dispatch)
```

## Built-in Agents

Chief Wiggum provides these agents out of the box:

| Agent | Purpose | Tools |
|-------|---------|-------|
| `chief-wiggum:recon` | Scan codebase, identify patterns | Read, Glob, Grep |
| `chief-wiggum:implement` | Write code to spec | Read, Write, Edit, Bash, Glob, Grep |
| `chief-wiggum:test` | Write and run tests | Read, Write, Edit, Bash, Glob, Grep |
| `chief-wiggum:review` | Security and pattern review | Read, Glob, Grep |
| `chief-wiggum:merge` | Rebase and merge prep | Read, Write, Edit, Bash, Glob, Grep |

## Using Custom Agents

Any Claude Code agent can be used. Just reference it by its full name:

```markdown
### LINT
Agent: my-plugin:linter

### DOCS
Agent: docs-plugin:api-documenter

### DEPLOY
Agent: devops:deploy-checker
```

The agent must be installed as a Claude Code plugin. Chief Wiggum just orchestrates - it doesn't own the agents.

## Creating Your Own Agents

Create agents as a Claude Code plugin. In your plugin's `agents/` directory:

```markdown
---
name: security-review
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
```

Then reference it as `your-plugin:security-review` in task files.

## Human Checkpoints

Use `Agent: human` for stages that require manual intervention:

```markdown
### PLAN
Agent: human
- [ ] Define verification command
- [ ] Set constraints
- [ ] Approve scope
```

Human stages don't dispatch - you advance them manually after completing the checklist.

## The Orchestration Model

```
┌─────────────────────────────────────────────────────────────┐
│  Task File (markdown)                                       │
│                                                             │
│  ### RESEARCH                                               │
│  Agent: chief-wiggum:recon       ──────┐                   │
│                                         │                   │
│  ### IMPLEMENT                          │                   │
│  Agent: chief-wiggum:implement   ──────┤ References        │
│                                         │                   │
│  ### SECURITY                           │                   │
│  Agent: acme:security-scan       ──────┘                   │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  Claude Code                                                │
│                                                             │
│  Resolves agents from installed plugins:                   │
│    - chief-wiggum:recon → chief-wiggum plugin              │
│    - acme:security-scan → acme plugin                      │
│                                                             │
│  Spawns the appropriate subagent for each stage            │
└─────────────────────────────────────────────────────────────┘
```

Chief Wiggum is the **orchestration layer**. Agents are defined wherever makes sense:
- **Shared agents** → Published plugins
- **Team agents** → Team's private plugin
- **Personal agents** → User's Claude Code config
