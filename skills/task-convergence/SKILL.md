---
name: task-convergence
description: How to write tasks and prompts that converge toward completion through autonomous iteration
---

# Task Convergence

This skill teaches you to write tasks that reliably complete through autonomous iteration.

## Core Insight

The traditional model: Human directs → Claude executes → Human reviews → Repeat

The convergent model: Human writes verifiable task → Claude iterates autonomously → System signals completion

**The skill shifts from "directing Claude" to "writing tasks that converge."**

## What Makes a Task Converge?

A task converges when:

1. **Success is verifiable by a command** - Not subjective, not "looks good"
2. **Errors provide directional feedback** - Each failure tells you what to fix
3. **Each iteration gets closer to done** - Not oscillating, not expanding scope

### Convergent vs Divergent Tasks

| Convergent ✓ | Divergent ✗ |
|-------------|-------------|
| "Add rate limiting that passes these tests" | "Improve API performance" |
| "Fix type errors so `tsc` passes" | "Clean up the code" |
| "Migrate User model to Prisma schema" | "Modernize the database layer" |
| "Add input validation per OpenAPI spec" | "Make the API more robust" |

## The Verification Command

Every dispatchable task MUST have a verification command that outputs `DONE` on success.

### Good Verification Commands

```bash
# Specific test must pass
npm test -- --grep "rate limiter" && echo "DONE"

# Multiple checks composed
npm run lint && npm test && npm run build && echo "DONE"

# Type checking
npx tsc --noEmit && echo "DONE"

# Migration verification
npm run db:migrate && npm run db:validate && echo "DONE"

# Contract test
npm run test:api -- --contract openapi.yaml && echo "DONE"
```

### Bad Verification Commands

```bash
# No success signal
npm test

# Subjective
# "Code looks clean"

# Too broad
npm run all-tests && echo "DONE"  # 1000 tests, but which one matters?

# External dependency
curl https://api.example.com/health  # Network-dependent
```

## Task File Structure

```markdown
# Task Name

## Type
mechanical | exploratory | architectural

## Objective
One sentence describing the done state.

## Verification Command
```bash
specific-command && echo "DONE"
```

## Constraints
- What NOT to do
- Files NOT to touch
- Patterns to avoid

## Context Files
- path/to/relevant/file.ts
- path/to/related/test.ts

## Max Iterations
20

## Prompt
[The actual instructions Claude receives]

After each change, run:
```bash
[verification command]
```

If it passes, output: DONE
If it fails, read the error, fix the issue, try again.
```

## Recognizing Convergence

### Signs of Convergence (Good)

- Errors become more specific over iterations
- Fewer files changing per iteration
- Test failure count decreasing
- Error messages reference later stages (build → test → lint)
- Time between iterations decreasing

### Signs of Divergence (Needs Intervention)

- Same error appears 3+ times in a row
- More files changing over time
- Oscillating between two states
- Errors in unrelated areas appearing
- Scope expanding ("while I'm here, I'll also...")

## When NOT to Dispatch

Some tasks should not be dispatched autonomously:

1. **No objective verification** - "Make it better" has no command
2. **Requires human judgment** - Design decisions, UX choices
3. **Security-sensitive** - Auth changes, permission models
4. **Exploratory** - "Figure out why X happens"
5. **Architectural** - Changes affecting multiple systems

For these, use Claude interactively with human in the loop.

## Writing Prompts That Converge

### Structure

```
[Clear objective - one sentence]

[Specific constraints - what NOT to do]

[Entry point - where to start reading]

[Verification - exactly how to check]

[Escape hatch - when to stop and ask]
```

### Example: Rate Limiter Task

```markdown
Implement IP-based rate limiting for the /api/auth/* endpoints.

Constraints:
- Do not modify existing auth logic
- Use the existing Redis connection
- Do not add new dependencies

Start by reading:
- src/middleware/index.ts
- src/config/redis.ts
- tests/api/auth.test.ts

Verification:
```bash
npm test -- --grep "rate limit" && echo "DONE"
```

If the same test fails 3 times with the same error, stop and explain what's blocking you.
```

### Anti-Pattern: Vague Prompt

```markdown
Make the auth system more secure.

Look at the auth code and improve it.

Let me know when you're done.
```

This will never converge because:
- "More secure" is subjective
- "Improve" has no bounds
- "Let me know" requires human judgment

## Iteration History Analysis

When reviewing task progress, look at the iterations_history:

```json
{
  "iterations_history": [
    {"iter": 1, "outcome": "missing import"},
    {"iter": 2, "outcome": "type error: string vs number"},
    {"iter": 3, "outcome": "test timeout"},
    {"iter": 4, "outcome": "1 test failing: edge case"},
    {"iter": 5, "outcome": "all tests pass"}
  ]
}
```

**Converging pattern**: Errors get more specific, moving through stages

```json
{
  "iterations_history": [
    {"iter": 1, "outcome": "cannot find module"},
    {"iter": 2, "outcome": "cannot find module"},
    {"iter": 3, "outcome": "cannot find module"}
  ]
}
```

**Stuck pattern**: Same error repeated - needs human input

## Max Iterations

Set `max_iterations` based on task complexity:

| Task Type | Typical Max |
|-----------|-------------|
| Single file fix | 5-10 |
| Feature implementation | 15-25 |
| Migration | 20-30 |
| Refactor with tests | 25-40 |

If a task consistently hits max iterations, the task definition needs work, not more iterations.

## Summary

1. **Write verification commands first** - If you can't verify it, you can't dispatch it
2. **Constrain scope explicitly** - List what NOT to do
3. **Provide entry points** - Tell Claude where to start reading
4. **Set escape hatches** - Define when to stop and ask
5. **Monitor convergence** - Watch iteration history for patterns
6. **Know when not to dispatch** - Some tasks need humans in the loop

The goal is not to remove humans from the loop, but to remove humans from the **iteration** loop while keeping them in the **task definition** loop.
