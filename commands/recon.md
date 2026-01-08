---
name: recon
description: Scan the codebase and identify actionable improvements
arguments:
  - name: scope
    description: Directory or file pattern to scan (default ".")
    required: false
    default: "."
---

# Recon Scan

Analyze the codebase at `$ARGUMENTS.scope` and identify actionable, dispatchable improvements.

## Output Format

For each finding, output one line in this exact format:

```
- [ ] [category:confidence:effort] Description — `path/to/file`
```

**Categories:** `bug`, `performance`, `security`, `refactor`, `test`, `debt`
**Confidence:** `high`, `medium`, `low`
**Effort:** `small`, `medium`, `large`

## Example Output

```
- [ ] [bug:high:small] Null check missing before array access — `src/api/users.ts:42`
- [ ] [security:high:medium] SQL query built with string concatenation — `src/db/queries.ts`
- [ ] [test:medium:small] No tests for edge case when user array is empty — `src/services/auth.ts`
- [ ] [performance:medium:large] N+1 query in user listing endpoint — `src/routes/users.ts`
- [ ] [debt:low:small] Unused import left after refactor — `src/utils/helpers.ts`
```

## What to Look For

**DO identify:**
- Code that could cause runtime bugs (null/undefined access, type coercion issues)
- Performance bottlenecks (N+1 queries, unnecessary re-renders, blocking I/O)
- Security vulnerabilities (injection, XSS, auth bypasses, exposed secrets)
- Missing tests for critical code paths
- Obvious code smells (dead code, copy-paste duplication, overly complex functions)

**DO NOT suggest:**
- Style/formatting changes (that's what linters are for)
- Documentation additions
- Dependency updates (unless security-critical)
- Subjective "improvements" that can't be verified
- Architectural changes without clear bugs/issues

## Dispatchability Check

For each finding, ask: "Can I write a verification command for this?"

- ✓ "Fix null check" → `npm test -- --grep "handles null user"`
- ✓ "Add parameterized query" → `npm run lint:security && npm test`
- ✗ "Improve code readability" → No objective verification
- ✗ "Consider refactoring" → Too vague

Only output findings that could become dispatchable tasks.

## Scanning Strategy

1. Start with high-signal files: tests, routes, API handlers
2. Follow imports to understand data flow
3. Look for error handling patterns (or lack thereof)
4. Check for common vulnerability patterns
5. Review recent git changes for incomplete work

## Output Location

Write findings to: `$CHIEF_WIGGUM_VAULT/tasks/RECON.md`

Include a header with scan metadata:

```markdown
# Recon Scan

**Scope:** $ARGUMENTS.scope
**Date:** [current date]
**Files scanned:** [count]

## Findings

[findings here]
```

Begin scanning now.
