# Stage Pipelines

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
Verification: `npm test -- --grep "rate limit"`

### TEST
Agent: test
Verification: `npm run test:coverage -- --threshold 80`

### REVIEW
Agent: review

### MERGE
Agent: merge
```

## Stage Navigation

| Keymap | Action |
|--------|--------|
| `gn` | Advance to next stage (mark current done) |
| `gp` | Regress to previous stage |
| `<CR>` | Dispatch current stage to its agent |
| `<Space>` | Toggle checklist item |

The `<- ACTIVE` marker shows which stage is current. Dispatching runs the agent for that stage with the stage's verification command.

## Default Stage Agents

| Stage | Agent | Purpose |
|-------|-------|---------|
| RESEARCH | recon | Scan codebase, identify patterns |
| PLAN | human | Requires human decision-making |
| IMPLEMENT | implement | Write the code |
| TEST | test | Add test coverage |
| REVIEW | review | Check for bugs, security, patterns |
| MERGE | merge | Rebase and prepare for merge |

## Customizing Stages

You can override the default stages and agents in your config:

```lua
require("chief-wiggum").setup({
  default_stages = { "RESEARCH", "PLAN", "IMPLEMENT", "TEST", "REVIEW", "MERGE" },

  agent_for_stage = {
    RESEARCH = "recon",
    PLAN = "human",         -- "human" means don't dispatch
    IMPLEMENT = "implement",
    TEST = "test",
    REVIEW = "review",
    MERGE = "merge",
  },
})
```
