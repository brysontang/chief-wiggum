# {{TASK_NAME}}

## Type

<!-- One of: mechanical | exploratory | architectural -->
<!-- mechanical: Clear verification, can run autonomously -->
<!-- exploratory: Needs human judgment, don't dispatch -->
<!-- architectural: Needs discussion, don't dispatch -->
mechanical

## Objective

<!-- One sentence. What does "done" look like? Be specific. -->

## Verification Command

<!-- MOST IMPORTANT SECTION -->
<!-- This command MUST output "DONE" when the task is complete -->
<!-- If you can't write this, the task isn't dispatchable -->

```bash

```

## Constraints

<!-- What Claude should NOT do -->
<!-- Files NOT to modify -->
<!-- Patterns to avoid -->
<!-- Dependencies NOT to add -->

- Do not modify existing tests (only add new ones)
- Do not change the public API
- Do not add new dependencies

## Context Files

<!-- Files Claude should read first to understand the system -->
<!-- Be specific - don't just say "look at the codebase" -->

-
-

## Max Iterations

<!-- How many attempts before marking as stuck -->
<!-- Default: 20. Increase for complex migrations. -->
20

## Prompt

````
<!-- The actual instructions Claude receives -->
<!-- Be specific about what to do and what success looks like -->
<!-- Reference the verification command -->



After each significant change, verify with:
```bash
[paste verification command here]
```

If verification passes, output exactly: DONE
If verification fails, read the error message carefully, fix the issue, and try again.

If you encounter the same error 3 times, stop and output: STUCK: [description of what's blocking]
````

## Log

<!-- Auto-appended by hooks during execution -->
<!-- Format: [timestamp] iteration N: outcome -->
