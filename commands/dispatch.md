---
name: dispatch
description: Dispatch a task from the chief-wiggum queue and work on it autonomously
arguments:
  - name: task
    description: Task ID or path to the feature/task file
    required: true
---

# Dispatch Task

You are being dispatched to work on task: `$ARGUMENTS.task`

## Instructions

1. **Read the task file completely** - Understand the objective, constraints, and verification command
2. **Note the verification command** - This is how you will know when you are done
3. **Read any context files** mentioned in the task
4. **Follow the plan/prompt** in the task file
5. **After each significant change**, run the verification command
6. **When verification passes**, output exactly: `DONE`

## Critical Rules

- **DO NOT** output "DONE" until the verification command actually succeeds
- If you encounter the same error 3 times in a row, stop and explain what's blocking you
- If verification requires manual testing you cannot perform, explain what the user needs to verify
- Log significant progress to the task file's `## Log` section
- Respect the `## Constraints` section - do not modify files you're told not to touch

## Verification Pattern

After implementing changes:

```bash
# Run the verification command from the task file
# If it outputs DONE (or equivalent success), you're done
# If it fails, read the error, fix the issue, and try again
```

## Completion Signal

When the verification command succeeds, your final message must contain exactly:

```
DONE
```

This signals to the chief-wiggum hook system that the task is complete.

## If Stuck

If you cannot make progress after 3 similar attempts:

1. Output: `STUCK: <brief description of the blocker>`
2. The hook system will mark the task as needing human input
3. Wait for the user to provide guidance

## Post-Completion Report

After outputting `DONE`, also provide a brief report:

```markdown
## Summary

[1-2 sentences: what was accomplished]

## Files Modified

- `path/to/file.ts` - [brief description of change]
- `path/to/other.ts` - [brief description]

## Decisions Made

Were any non-obvious choices made that future work should know about?

- [ ] **New pattern introduced:** [description, why this pattern]
- [ ] **Gotcha discovered:** [something surprising you encountered]
- [ ] **Alternative rejected:** [what you didn't do, and why]
- [ ] **Exception to existing pattern:** [if you deviated, why]

## Context Files Updated

Did you update any MODULE.md or CONTEXT.md files? If not, should you have?

- [ ] Updated: [path]
- [ ] Should create: [path] - [why this module needs docs]

## Suggested Follow-up

Any related work that should be done next?

- [ ] [task idea]
```

This report helps build the decision trace for future reference and identifies any architectural decisions that should become ADRs.

---

Now read the task file at `$ARGUMENTS.task` and begin working.
