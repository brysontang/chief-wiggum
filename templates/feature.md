# {{TASK_NAME}}

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

<!-- Agent options:
     - Built-in: recon, implement, test, review, merge
     - Custom: my-plugin:custom-agent (any Claude Code agent)
     - Manual: human (requires manual advancement)

     Verification: customize per project (npm test, pytest, go test, etc.)
-->

### RESEARCH ← ACTIVE
Agent: recon
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
Agent: implement
- [ ] Implementation tasks here
- [ ] Update MODULE.md if new patterns
Verification: `npm test`

### TEST
Agent: test
- [ ] Write unit tests
- [ ] Write integration tests
- [ ] Verify coverage threshold
Verification: `npm run test:coverage -- --threshold 80`

### REVIEW
Agent: review
- [ ] Security review
- [ ] Pattern compliance
- [ ] Human approval
Verification: `echo "Human approved"`

### MERGE
Agent: merge
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
