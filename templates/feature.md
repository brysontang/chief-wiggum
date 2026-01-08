# {{TASK_NAME}}

## Options

<!-- Task-level settings -->
auto_advance: false   <!-- Set to true for fully autonomous mode (skips human stages) -->
validate_loop: false  <!-- Set to true to verify Objective at end, restart if not met -->

## Worktree

<!-- Populated when worktree is created -->
Path:
Branch:

## Objective

<!-- One sentence. What does "done" look like? -->

## Constraints

<!-- What Claude should NOT do -->
- Do not modify existing tests (only add new ones)
- Do not change the public API
- Do not add new dependencies

## Context Files

<!-- Files Claude should read first -->
-
-

## Stages

<!-- Agent format: plugin:agent-name (any Claude Code agent)
     - chief-wiggum:recon, chief-wiggum:implement, etc.
     - your-plugin:custom-agent
     - human (manual checkpoint, no dispatch)

     Verification: customize per project (npm test, pytest, go test, etc.)
-->

### RESEARCH ← ACTIVE
Agent: chief-wiggum:recon
- [ ] Investigate existing patterns
- [ ] Check adjacent MODULE.md files
- [ ] Note dependencies and dependents
→ Notes:

### PLAN
Agent: human
- [ ] Define verification command
- [ ] Set constraints
- [ ] Approve scope
- [ ] Review research notes

### IMPLEMENT
Agent: chief-wiggum:implement
- [ ] Implementation tasks here
- [ ] Update MODULE.md if new patterns
Verification: `npm test`

### TEST
Agent: chief-wiggum:test
- [ ] Write unit tests
- [ ] Write integration tests
- [ ] Verify coverage threshold
Verification: `npm run test:coverage -- --threshold 80`

### REVIEW
Agent: chief-wiggum:review
- [ ] Security review
- [ ] Pattern compliance
- [ ] Human approval
Verification: `echo "Human approved"`

### MERGE
Agent: chief-wiggum:merge
- [ ] Rebase on main
- [ ] Resolve conflicts
- [ ] Final verification
- [ ] Squash merge
Verification: `npm run lint && npm test && npm run build`

## Decisions Made

<!-- Record non-obvious choices for future reference -->
<!-- Link to [[decisions/YYYY-MM-topic]] for significant decisions -->

## Log

<!-- Auto-appended by agents. This IS the iteration history. -->
<!-- Format: [timestamp] STAGE iter N: outcome -->
