# Configuration

## Full Configuration

```lua
require("chief-wiggum").setup({
  -- Where all chief-wiggum data lives
  vault_path = "~/.chief-wiggum",

  -- Maximum concurrent agents
  max_agents = 5,

  -- Maximum turns per dispatch (cost control)
  max_turns = 20,

  -- Auto-reload buffers on status change
  auto_reload = true,

  -- Show system notifications (macOS + Linux)
  notify_on_complete = true,

  -- Iterations with same error before stuck
  stuck_threshold = 3,

  -- Git worktree settings
  worktree_base = ".worktrees",    -- Relative to project root
  auto_create_worktree = false,    -- Create worktree on first dispatch

  -- Default stages for new tasks
  default_stages = { "RESEARCH", "PLAN", "IMPLEMENT", "TEST", "REVIEW", "MERGE" },

  -- Default agent for each stage
  agent_for_stage = {
    RESEARCH = "recon",
    PLAN = "human",         -- "human" means don't dispatch, requires manual work
    IMPLEMENT = "implement",
    TEST = "test",
    REVIEW = "review",
    MERGE = "merge",
  },

  -- Override which tool an agent uses (optional)
  -- Only 'claude' is fully supported. Other tools use template substitution.
  agent_tool = {
    -- implement = "claude",
    -- review = "aider",
  },

  -- Dispatch command templates
  -- Only 'claude' is fully supported. Other tools require manual configuration.
  dispatch_commands = {
    claude = "...", -- handled specially with --agents and --max-turns
    -- Add custom templates for other tools as needed
  },

  -- Keymaps (set to false to disable)
  keymaps = {
    status = "<leader>ws",
    dispatch = "<leader>wd",
    command = "<leader>wc",
    recon = "<leader>wr",
    queue = "<leader>wq",
    advance = "<leader>wn",
    regress = "<leader>wp",
  },
})
```

## Terminal Alternatives

Currently only tmux is supported. The dispatch logic is hardcoded for tmux. PRs welcome for other terminals.

## Per-Project Configuration

Use `./.wiggum` for per-project vaults:

```lua
require("chief-wiggum").setup({
  vault_path = "./.wiggum",
})
```
