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

  -- Show system notifications
  notify_on_complete = true,

  -- Iterations with same error before stuck
  stuck_threshold = 3,

  -- Git worktree settings
  worktree_base = ".worktrees",   -- Relative to project root
  auto_create_worktree = true,    -- Create worktree on first dispatch

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
  agent_tool = {
    -- implement = "claude",
    -- review = "codex",
  },

  -- Commands for each AI tool
  dispatch_commands = {
    claude = "tmux new-window -n '%s' 'cd %s && CHIEF_WIGGUM_TASK_ID=%s CHIEF_WIGGUM_VAULT=%s claude'",
    codex = "tmux new-window -n '%s' 'cd %s && CHIEF_WIGGUM_TASK_ID=%s codex --task-file %s'",
    aider = "tmux new-window -n '%s' 'cd %s && CHIEF_WIGGUM_TASK_ID=%s aider --message-file %s'",
    ollama = "tmux new-window -n '%s' 'cd %s && CHIEF_WIGGUM_TASK_ID=%s ollama run %s < %s'",
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

### Kitty

```lua
dispatch_commands = {
  claude = "kitty @ new-window --title '%s' bash -c 'CHIEF_WIGGUM_TASK_ID=%s CHIEF_WIGGUM_VAULT=%s claude'"
}
```

### iTerm2

```lua
dispatch_commands = {
  claude = "osascript -e 'tell app \"iTerm\" to create window with default profile command \"CHIEF_WIGGUM_TASK_ID=%s CHIEF_WIGGUM_VAULT=%s claude\"'"
}
```

### Wezterm

```lua
dispatch_commands = {
  claude = "wezterm cli spawn --new-window -- bash -c 'CHIEF_WIGGUM_TASK_ID=%s CHIEF_WIGGUM_VAULT=%s claude'"
}
```

## Per-Project Configuration

Use `./.wiggum` for per-project vaults:

```lua
require("chief-wiggum").setup({
  vault_path = "./.wiggum",
})
```
