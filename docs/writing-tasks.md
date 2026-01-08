# Writing Good Tasks

## The Verification Command

Every task needs a verification command that outputs `DONE` on success:

```bash
# Good: Specific and measurable
npm test -- --grep "rate limit" && echo "DONE"

# Good: Multiple checks
npm run lint && npm test && npm run build && echo "DONE"

# Bad: No completion signal
npm test

# Bad: Too broad
npm run test:all && echo "DONE"
```

## Convergent vs Divergent

**Convergent tasks** (dispatch these):
- Errors become more specific each iteration
- Fewer files changing per iteration
- Clear path to DONE

**Divergent tasks** (don't dispatch these):
- Same error 3+ times
- Scope keeps expanding
- Requires subjective judgment

## Task Types

| Type | Dispatch? | Description |
|------|-----------|-------------|
| `mechanical` | Yes | Clear verification, runs autonomously |
| `exploratory` | No | Needs human judgment mid-task |
| `architectural` | No | Needs discussion, affects many systems |

## Task File Structure

```markdown
# Rate Limiter

## Objective
Add IP-based rate limiting to /api/auth/* endpoints.

## Constraints
- Do not modify existing auth logic
- Use existing Redis connection
- Do not add new dependencies

## Context Files
- src/middleware/index.ts
- src/config/redis.ts

## Stages

### IMPLEMENT <- ACTIVE
Agent: implement
Verification: `npm test -- --grep "rate limit" && echo DONE`

## Log
<!-- Auto-appended by agents -->
```

## Recon Scan

The recon command scans your codebase for actionable improvements:

```vim
:ChiefWiggumRecon src/
```

Output format:
```
- [ ] [bug:high:small] Null check missing — `src/api/users.ts:42`
- [ ] [security:high:medium] SQL injection risk — `src/db/queries.ts`
- [ ] [test:medium:small] No test for empty array — `src/utils/stats.ts`
```

Each finding can be converted into a dispatchable task.
