# Philosophy

Chief Wiggum is inspired by the [ralph-wiggum](https://paddo.dev/blog/ralph-wiggum-autonomous-loops/) autonomous loop pattern.

## Core Insights

1. **Verification commands are everything** - A task isn't dispatchable unless completion can be verified by a command that outputs "DONE"
2. **Failures are data** - Each iteration that doesn't complete provides directional feedback
3. **The skill shifts** - From "directing Claude step by step" to "writing prompts that converge toward correct solutions"
4. **State lives in files, not context** - Every dispatch is fresh; the filesystem is the memory

## Why Fresh Contexts

Chief Wiggum dispatches agents with **fresh context windows every time**. This is intentional:

```
Traditional approach:
┌─────────────────────────────────────────┐
│ Context Window                          │
│ ┌─────────────────────────────────────┐ │
│ │ iter 1: tried X, failed            │ │
│ │ iter 2: tried Y, failed            │ │
│ │ iter 3: tried Z, failed            │ │
│ │ iter 4: tried X again (forgot!)    │ │  ← Context pollution
│ │ iter 5: confused by old context    │ │
│ │ ...                                 │ │
│ │ iter N: context full, degraded     │ │
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘

Chief Wiggum approach:
┌─────────────┐   ┌─────────────┐   ┌─────────────┐
│ Fresh       │   │ Fresh       │   │ Fresh       │
│ Context     │   │ Context     │   │ Context     │
│             │   │             │   │             │
│ Read task → │   │ Read task → │   │ Read task → │
│ See log     │   │ See log     │   │ See log     │
│ Know state  │   │ Know state  │   │ Know state  │
└─────────────┘   └─────────────┘   └─────────────┘
      ↓                 ↓                 ↓
   task.md           task.md           task.md
   (updated)         (updated)         (updated)
```

**The agent doesn't remember. The files remember.**

Each dispatch reads:
- **The task file** - Objective, constraints, verification command
- **The ## Log section** - What previous iterations accomplished
- **MODULE.md files** - Patterns in the code
- **Git history** - What changed recently
- **The code itself** - Current state on disk

This eliminates context pollution and gives each iteration the agent's full attention.

## Tasks That Work

- Migrations with schema validation
- Test coverage for specific functions
- Refactors with linting gates
- API implementations with contract tests
- Bug fixes with regression tests

## Tasks That Don't Work

- "Improve performance" (how much?)
- "Clean up code" (by what standard?)
- "Make it better" (better how?)
- Anything subjective or requiring human judgment
