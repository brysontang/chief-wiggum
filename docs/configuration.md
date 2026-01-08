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

  -- Dispatch command templates (named placeholders)
  -- Available: {task_name}, {worktree}, {task_id}, {vault}, {task_file}, {model}, {prompt}
  dispatch_commands = {
    claude = "tmux new-window -n {task_name} 'cd {worktree} && CHIEF_WIGGUM_TASK_ID={task_id} CHIEF_WIGGUM_VAULT={vault} claude {prompt}'",
    aider = "tmux new-window -n {task_name} 'cd {worktree} && CHIEF_WIGGUM_TASK_ID={task_id} aider --message {prompt}'",
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

Note: Only `claude` tool is fully supported with automatic `--agents` and `--max-turns` flags. These templates show the basic structure for other terminals.

### Kitty

```lua
dispatch_commands = {
  claude = "kitty @ new-window --title {task_name} bash -c 'cd {worktree} && CHIEF_WIGGUM_TASK_ID={task_id} CHIEF_WIGGUM_VAULT={vault} claude {prompt}'"
}
```

### iTerm2

```lua
dispatch_commands = {
  claude = "osascript -e 'tell app \"iTerm\" to create window with default profile command \"cd {worktree} && CHIEF_WIGGUM_TASK_ID={task_id} CHIEF_WIGGUM_VAULT={vault} claude\"'"
}
```

### Wezterm

```lua
dispatch_commands = {
  claude = "wezterm cli spawn --new-window -- bash -c 'cd {worktree} && CHIEF_WIGGUM_TASK_ID={task_id} CHIEF_WIGGUM_VAULT={vault} claude {prompt}'"
}
```

## Per-Project Configuration

Use `./.wiggum` for per-project vaults:

```lua
require("chief-wiggum").setup({
  vault_path = "./.wiggum",
})
```
