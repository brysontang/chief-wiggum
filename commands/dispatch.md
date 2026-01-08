---
name: dispatch
description: Dispatch to work on a specific stage of a task
arguments:
  - name: task
    description: Task ID or path to the feature/task file
    required: true
  - name: stage
    description: Stage to work on (e.g., IMPLEMENT, TEST). Defaults to current active stage.
    required: false
  - name: agent
    description: Agent to use. Defaults to stage's configured agent.
    required: false
---

# Dispatch Task

You are being dispatched to work on: `$ARGUMENTS.task`
Stage: `$ARGUMENTS.stage` (or current active)
Agent: `$ARGUMENTS.agent` (or stage default)

---

## Context is Fresh

**You are starting with a clean context window. You have no memory of previous sessions.**

Everything you need to know is in:
1. **The task file** - Objective, constraints, verification command
2. **The ## Log section** - What previous iterations accomplished
3. **MODULE.md files** - Patterns in the code
4. **Git history** - What changed recently (`git log --oneline -10`)
5. **The code itself** - Current state on disk

Do not assume context from previous conversations. There are none.
Read the state. Do the work. Update the state.

---

## Instructions

1. **Read the task file completely**
   - Find the current active stage (marked with `← ACTIVE`)
   - Note the stage's verification command
   - Read the `## Log` section to see what previous iterations did

2. **Run context-sync protocol**
   - Check for MODULE.md in directories you'll modify
   - Read context files listed in the task
   - Understand existing patterns before changing anything

3. **Do the work for THIS stage only**
   - Stay within the stage's scope
   - Run verification after each significant change
   - Don't skip ahead to other stages

4. **Update state in files**
   - Append to `## Log` section with your progress
   - Update `## Decisions Made` if you made non-obvious choices
   - Update MODULE.md if you introduced new patterns

5. **Signal completion**
   - `DONE` when verification passes
   - `STUCK: <reason>` if blocked after 3 similar attempts

---

## State Lives in Files

### What you read:
```
## Log
- [10:42] IMPLEMENT iter 1: missing import for Redis
- [10:45] IMPLEMENT iter 2: type error in middleware
```

This tells you: two previous attempts, what went wrong. You don't need to "remember" - just read.

### What you write:
```
## Log
- [10:42] IMPLEMENT iter 1: missing import for Redis
- [10:45] IMPLEMENT iter 2: type error in middleware
- [10:51] IMPLEMENT iter 3: added import, fixed types, tests pass
```

Next iteration (or next human) reads this and knows what happened.

---

## Verification Pattern

Each stage has its own verification command. Find it in the stage section:

```markdown
### IMPLEMENT
Agent: implement
- [ ] Implementation tasks
Verification: `npm test -- --grep "rate limit" && echo DONE`
```

Run this command. If it outputs DONE, you're done with the stage.

---

## Completion Signals

### Stage Complete
```
DONE
```
The stage verification passed. The hook system will record this.

### Stuck
```
STUCK: <brief description>
```
You tried 3+ times with similar failures. Need human input.

### Ready to Merge (MERGE stage only)
```
READY_TO_MERGE
```
The branch is rebased, tests pass, ready for human to merge.

---

## Post-Stage Report

After `DONE`, append to the task file's `## Log`:

```markdown
- [HH:MM] STAGE iter N: DONE - brief summary
  - Files: path/to/changed.ts, path/to/other.ts
  - Decision: chose X over Y because Z
  - Gotcha: watch out for W
```

This IS the memory. Next agent reads this.

---

## Critical Rules

- **DO NOT** output "DONE" until verification actually succeeds
- **DO NOT** assume context from "previous conversations" - there are none
- **DO** read the `## Log` to understand what happened before
- **DO** write to `## Log` so next iteration knows what you did
- **DO** update MODULE.md if you introduce new patterns
- **DO** stay within your stage's scope

---

Now read the task file and begin working on the current stage.
