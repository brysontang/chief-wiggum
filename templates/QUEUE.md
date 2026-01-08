# Task Queue

Tasks ready for dispatch. Move to "Dispatched" when running, "Done" when complete.

## Priority

High-impact tasks that should be done first.

- [ ] <!-- [[features/task-name]] - brief description -->

## Ready

Tasks with verification commands that can be dispatched.

- [ ] <!-- [[features/task-name]] - brief description -->

## Needs Work

Tasks that need better verification commands or clearer scope.

- [ ] <!-- Task idea - what's missing before it can be dispatched? -->

## Blocked

Tasks waiting on external factors.

- [ ] <!-- [[features/task-name]] - what's blocking? -->

## Dispatched

Currently running agents.

<!-- Auto-populated from status -->

## Done Today

- [x] <!-- [[features/task-name]] - completed in N iterations -->

---

## Creating New Tasks

1. `:ChiefWiggumNew <name>` or copy [[templates/feature]]
2. Write a clear **Objective** (one sentence, done state)
3. Write a **Verification Command** that outputs `DONE` on success
4. Add **Constraints** (what NOT to do)
5. Write the **Prompt** Claude will receive
6. Dispatch with `<leader>wd` on the file

### Good Verification Commands

```bash
# Specific test
npm test -- --grep "rate limiter" && echo "DONE"

# Multiple checks
npm run lint && npm test && npm run build && echo "DONE"

# Type checking
npx tsc --noEmit && echo "DONE"
```

### Tasks That Don't Work

- "Improve performance" - How much? No objective measure
- "Clean up code" - By what standard?
- "Make it better" - Better how?

If you can't write a verification command, the task isn't dispatchable.
