---@class ChiefWiggumConfig
---@field vault_path string Path to the vault directory
---@field status_dir string Subdirectory for status files
---@field templates_dir string Subdirectory for templates
---@field max_agents number Maximum concurrent agents
---@field auto_reload boolean Auto-reload files when status changes
---@field notify_on_complete boolean Show notification when task completes
---@field stuck_threshold number Iterations with same error before marking stuck
---@field worktree_base string Base directory for worktrees
---@field auto_create_worktree boolean Create worktree on first dispatch
---@field default_stages string[] Default stage names
---@field default_agent string Default agent if not specified
---@field agent_for_stage table<string, string> Map stage names to agent names
---@field dispatch_commands table<string, string> Map tool names to dispatch command templates
---@field agent_tool table<string, string> Override tool for specific agents

local M = {}

---@type ChiefWiggumConfig
M.defaults = {
  -- Where all chief-wiggum data lives
  -- Use "~/.chief-wiggum" for global, "./.wiggum" for per-project
  vault_path = vim.fn.expand("~/.chief-wiggum"),

  -- Subdirectories within the vault
  status_dir = "status",
  templates_dir = "templates",

  -- Maximum number of concurrent agents
  max_agents = 5,

  -- Automatically reload buffers when status files change
  auto_reload = true,

  -- Show macOS notification when task completes or gets stuck
  notify_on_complete = true,

  -- Number of iterations with identical errors before marking as stuck
  stuck_threshold = 3,

  -- Worktree settings
  -- Base directory for worktrees (relative to git root)
  worktree_base = ".worktrees",
  -- Automatically create worktree on first dispatch
  auto_create_worktree = true,

  -- Stage settings
  default_stages = { "RESEARCH", "PLAN", "IMPLEMENT", "TEST", "REVIEW", "MERGE" },

  -- Default agent if not specified in stage
  default_agent = "implement",

  -- Map stage names to default agent names
  agent_for_stage = {
    RESEARCH = "recon",
    PLAN = "human",
    IMPLEMENT = "implement",
    TEST = "test",
    REVIEW = "review",
    MERGE = "merge",
  },

  -- Dispatch command templates for each tool
  -- Placeholders: %1=task_name, %2=worktree_path, %3=task_id, %4=vault_path, %5=prompt_file, %6=model
  dispatch_commands = {
    -- Claude Code (default)
    claude = "tmux new-window -n '%s' 'cd %s && CHIEF_WIGGUM_TASK_ID=%s CHIEF_WIGGUM_VAULT=%s claude'",

    -- OpenAI Codex CLI (hypothetical, adjust to actual CLI)
    codex = "tmux new-window -n '%s' 'cd %s && CHIEF_WIGGUM_TASK_ID=%s codex --task-file %s'",

    -- OpenCode
    opencode = "tmux new-window -n '%s' 'cd %s && CHIEF_WIGGUM_TASK_ID=%s opencode'",

    -- Aider
    aider = "tmux new-window -n '%s' 'cd %s && CHIEF_WIGGUM_TASK_ID=%s aider --message-file %s'",

    -- Ollama (local models)
    ollama = "tmux new-window -n '%s' 'cd %s && CHIEF_WIGGUM_TASK_ID=%s ollama run %s < %s'",

    -- Cursor (if CLI available)
    cursor = "tmux new-window -n '%s' 'cd %s && CHIEF_WIGGUM_TASK_ID=%s cursor --task %s'",

    -- Generic (reads prompt from file, outputs to stdout)
    generic = "tmux new-window -n '%s' 'cd %s && cat %s | your-ai-tool'",
  },

  -- Override which tool to use for specific agents (by agent name)
  -- If not specified, looks at agent file frontmatter, then defaults to "claude"
  agent_tool = {
    -- Example overrides:
    -- review = "codex",     -- Use different latent space for review
    -- security = "codex",   -- Harsh security review
    -- test = "ollama",      -- Fast local test generation
    -- docs = "opencode",    -- Documentation generation
  },

  -- Keymaps (set to false to disable)
  keymaps = {
    status = "<leader>ws",          -- Show status window
    dispatch = "<leader>wd",        -- Dispatch current stage
    command = "<leader>wc",         -- Open COMMAND.md
    recon = "<leader>wr",           -- Run recon scan
    queue = "<leader>wq",           -- Open QUEUE.md
    advance = "<leader>wn",         -- Advance to next stage
    regress = "<leader>wp",         -- Go back to previous stage
    toggle = "<leader>wt",          -- Toggle checklist item
    worktree = "<leader>ww",        -- Open worktree in explorer
  },

  -- File explorer to use for worktree navigation
  -- Options: "netrw", "neo-tree", "oil", "cd"
  file_explorer = "netrw",
}

---@type ChiefWiggumConfig
M.options = {}

---Setup configuration with user overrides
---@param opts? table User configuration overrides
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})

  -- Expand paths
  M.options.vault_path = vim.fn.expand(M.options.vault_path)
end

---Get current configuration
---@return ChiefWiggumConfig
function M.get()
  return M.options
end

return M
