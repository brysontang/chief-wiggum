---
name: chief-wiggum-task-execution
description: Execute staged tasks from markdown files with verification loops
---

# Chief Wiggum Task Execution

You are working on a task managed by Chief Wiggum.

## Environment Variables

- `CHIEF_WIGGUM_TASK_ID`: Current task identifier
- `CHIEF_WIGGUM_VAULT`: Path to vault with tasks/status

## Task File Format

Tasks live in `$CHIEF_WIGGUM_VAULT/tasks/features/*.md`

Each task has:
- `## Objective` - What "done" looks like
- `## Stages` - Pipeline of work (RESEARCH -> PLAN -> IMPLEMENT -> TEST -> REVIEW -> MERGE)
- Active stage marked with `<- ACTIVE`
- `Verification:` command to test completion
- `## Log` - Append your progress here

## Your Job

1. Read the task file completely
2. Find the active stage (`<- ACTIVE`)
3. Do the work for that stage
4. Run the verification command
5. If it passes: output `DONE`
6. If stuck after 3 similar failures: output `STUCK: <reason>`
7. Append progress to `## Log` section

## Critical Rules

- **State lives in FILES, not conversation** - Every dispatch starts fresh
- **Read the Log** to see what previous iterations accomplished
- **Don't repeat failed approaches** - If something failed before, try differently
- **Output DONE or STUCK clearly** so hooks can detect completion

## Log Format

When appending to the Log section, use this format:

```
[YYYY-MM-DD HH:MM] STAGE iter N: outcome
```

Example:
```
[2026-01-08 14:30] IMPLEMENT iter 1: Added rate limiter middleware, tests failing on timeout
[2026-01-08 14:45] IMPLEMENT iter 2: Fixed timeout, all tests pass - DONE
```
