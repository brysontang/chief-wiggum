# {{TASK_NAME}}

## Options

<!-- Task-level settings -->
auto_advance: true  <!-- YOLO mode: runs until complete or stuck -->

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

<!-- No human stages - fully autonomous pipeline -->

### RESEARCH ← ACTIVE
Agent: chief-wiggum:recon
- [ ] Investigate existing patterns
- [ ] Check adjacent MODULE.md files
- [ ] Note dependencies and dependents
→ Notes:

### IMPLEMENT
Agent: chief-wiggum:implement
- [ ] Implementation tasks here
- [ ] Update MODULE.md if new patterns
Verification: `npm test`

### TEST
Agent: chief-wiggum:test
- [ ] Write unit tests
- [ ] Write integration tests
Verification: `npm run test:coverage`

### REVIEW
Agent: chief-wiggum:review
- [ ] Security review
- [ ] Pattern compliance
Verification: `npm run lint`

## Decisions Made

<!-- Record non-obvious choices for future reference -->

## Log

<!-- Auto-appended by agents. This IS the iteration history. -->
<!-- Format: [timestamp] STAGE iter N: outcome -->
