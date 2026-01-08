# Stage Pipelines

Tasks flow through stages, each with its own agent and verification command.

## Stage Structure

```markdown
## Stages

### RESEARCH ← ACTIVE
Agent: chief-wiggum:recon
- [ ] Identify files that handle rate limiting
- [ ] Check existing middleware patterns
→ Notes:

### PLAN
Agent: human
- [ ] Define verification command
- [ ] Set constraints
- [ ] Approve scope

### IMPLEMENT
Agent: chief-wiggum:implement
- [ ] Implementation tasks here
Verification: `npm test -- --grep "rate limit"`

### TEST
Agent: chief-wiggum:test
- [ ] Write unit tests
Verification: `npm run test:coverage -- --threshold 80`

### REVIEW
Agent: chief-wiggum:review
- [ ] Security review
- [ ] Pattern compliance

### MERGE
Agent: chief-wiggum:merge
- [ ] Rebase on main
- [ ] Final verification
Verification: `npm run lint && npm test && npm run build`
```

## Stage Components

Each stage has:

| Component | Purpose |
|-----------|---------|
| **Agent** | Which Claude Code agent runs this stage (`plugin:agent-name`) |
| **Checklist** | Tasks to complete (checkboxes) |
| **Verification** | Command that must pass (exit 0) for completion |
| **Notes** | Agent findings (prefixed with `→`) |

## The Active Marker

The `← ACTIVE` marker shows which stage is current:

```markdown
### RESEARCH          # Done
### PLAN              # Done
### IMPLEMENT ← ACTIVE  # Current
### TEST              # Pending
```

When a stage completes, the marker automatically advances to the next stage.

## Stage Navigation

| Keymap | Action |
|--------|--------|
| `<leader>wn` | Advance to next stage (manual) |
| `<leader>wp` | Regress to previous stage |
| `<leader>wd` | Dispatch current stage to its agent |

## Verification Commands

Each stage can have a `Verification:` line. The agent runs this command to check completion.

**Project-specific examples:**

```markdown
# Node.js
Verification: `npm test`

# Python
Verification: `pytest tests/ -v`

# Go
Verification: `go test ./...`

# Rust
Verification: `cargo test`

# Simple file check
Verification: `grep "Hello, World!" hello.txt`
```

Customize these in your project's `.wiggum/templates/` to match your stack.

## Default Pipeline

The default `feature.md` template includes:

| Stage | Agent | Purpose |
|-------|-------|---------|
| RESEARCH | `chief-wiggum:recon` | Scan codebase, identify patterns |
| PLAN | `human` | Human checkpoint for decisions |
| IMPLEMENT | `chief-wiggum:implement` | Write the code |
| TEST | `chief-wiggum:test` | Add test coverage |
| REVIEW | `chief-wiggum:review` | Security and pattern review |
| MERGE | `chief-wiggum:merge` | Rebase and prepare for merge |

## Custom Pipelines

Create different templates for different workflows:

```
.wiggum/templates/
├── feature.md      # Full pipeline
├── bugfix.md       # Skip RESEARCH, lighter TEST
├── hotfix.md       # IMPLEMENT + REVIEW only
├── refactor.md     # Heavy on TEST
└── docs.md         # RESEARCH + IMPLEMENT only
```

Example `hotfix.md`:

```markdown
## Stages

### IMPLEMENT ← ACTIVE
Agent: chief-wiggum:implement
Verification: `npm test`

### REVIEW
Agent: chief-wiggum:review
Verification: `npm run lint`
```

## Human Stages

Stages with `Agent: human` are manual checkpoints:

```markdown
### PLAN
Agent: human
- [ ] Define verification command
- [ ] Set constraints
- [ ] Approve scope
```

These don't dispatch - you complete them manually and advance with `<leader>wn`.
