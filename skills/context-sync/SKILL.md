---
name: context-sync
description: Read and maintain living documentation before modifying code. Prevents Claude from missing architectural patterns.
---

# Context Sync Protocol

Before modifying any source file, follow this protocol. This prevents the common failure mode of "skimming complexity" - making changes that technically work but violate existing patterns or miss important context.

## Why This Matters

Claude tends to:
- Read the minimum needed to make a change
- Miss patterns established elsewhere in the codebase
- Introduce inconsistencies with existing code
- Overlook gotchas documented in adjacent files

This protocol forces comprehension before modification.

## The Protocol

### 1. Check for Context Doc

Before modifying any file in `src/`, look for documentation:

```
src/auth/
├── MODULE.md      ← Check here first
├── CONTEXT.md     ← Or here
├── README.md      ← Or here
├── index.ts
└── handlers/
```

Search pattern:
```bash
ls -la $(dirname $FILE)/{MODULE,CONTEXT,README}.md 2>/dev/null
```

### 2. Read Code First

Before reading docs, skim the actual implementation:
- What patterns does it use?
- What's the current state?
- What might the docs be wrong about?

This prevents blindly trusting outdated documentation.

### 3. Reconcile

If context doc exists but doesn't match code:

**UPDATE THE DOC FIRST**

This is critical. By updating the doc, you:
- Force yourself to understand what actually exists
- Leave better context for future work
- Catch your own misunderstandings early

If no context doc exists for a complex module:
- Consider creating one (especially if you struggled to understand it)
- At minimum, note patterns in your task log

### 4. Read Adjacent Context

From the module's context doc or imports, identify:
- What does this module depend on?
- What depends on this module?

Read THEIR context docs too. Changes here may affect them.

```
# If modifying src/auth/handlers/login.ts
# Check:
src/auth/MODULE.md           # Parent context
src/auth/handlers/MODULE.md  # Direct context
src/db/MODULE.md             # If we import from db/
src/api/MODULE.md            # If api/ imports from auth/
```

### 5. Then Proceed

Now you have:
- Current code state (not assumed state)
- Documented patterns and gotchas
- Understanding of upstream/downstream impacts

Only now should you make changes.

## Auto-Trigger

Activate this protocol when:
- About to modify files in `src/`, `lib/`, or `packages/`
- Task involves "add feature", "integrate", "refactor", "extend"
- You feel uncertain about existing patterns
- The file has more than ~100 lines
- The module has multiple files

## Context Doc Format

When creating context docs, use this format:

```markdown
# Module Name

## What This Does

One paragraph explaining the module's purpose and responsibility.

## Key Patterns

- **Pattern Name** - How and why it's used here
- **Another Pattern** - Description

## Public Interface

Functions/classes that other modules should use:

- `functionName(args)` - What it does, when to use it
- `ClassName` - Purpose, lifecycle

## Internal Details

Implementation details that matter:

- Why we chose X over Y
- Performance considerations
- Edge cases handled

## Dependencies

What this module imports and why:

- `path/to/dep` - Why we need it, what we use

## Dependents

What imports this module:

- `path/to/consumer` - How they use us, what would break

## Gotchas

Things that will bite you:

- Gotcha 1: Why it's surprising, how to handle it
- Gotcha 2: The trap and how to avoid it

## Related Decisions

Links to ADRs or decision docs:

- [[decisions/2024-01-auth-pattern]] - Why we auth this way

## Last Verified

YYYY-MM-DD by [human|claude]

Was the code still matching this doc on that date?
```

## Example: Before Modifying Auth Handler

Task: "Add rate limiting to login endpoint"

**Wrong approach:**
1. Open `src/auth/handlers/login.ts`
2. Add rate limiting code
3. Run tests
4. Done

**Context-sync approach:**
1. Check: `ls src/auth/{MODULE,CONTEXT,README}.md` → Found `MODULE.md`
2. Read `src/auth/handlers/login.ts` - see it uses a middleware pattern
3. Read `src/auth/MODULE.md` - mentions "all cross-cutting concerns go in middleware/"
4. Check: middleware already exists? `ls src/middleware/` → Yes, has `rateLimit.ts`
5. Read `src/middleware/MODULE.md` - shows how to configure rate limiters
6. Now implement: Use existing rate limit middleware, don't add inline code
7. Update `src/auth/MODULE.md` to note rate limiting is now applied

The context-sync approach:
- Discovered existing rate limiting infrastructure
- Followed established patterns
- Updated docs for future reference
- Avoided introducing inconsistency

## Integration with Chief Wiggum

Add to task prompts:

```markdown
## Pre-Implementation

Before modifying any source files:
1. Run context-sync protocol (see skills/context-sync)
2. List context docs you read
3. Note any patterns that affect your approach

## Context Docs Read
<!-- Fill this in before implementing -->
- [ ] path/to/MODULE.md
- [ ] path/to/other/MODULE.md
```

This makes context-sync part of the task verification - you can't claim DONE without documenting what context you consumed.
