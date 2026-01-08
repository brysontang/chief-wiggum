---@class ChiefWiggumConfig
---@field vault_path string Path to the vault directory
---@field status_dir string Subdirectory for status files
---@field templates_dir string Subdirectory for templates
---@field dispatch_cmd string Command template for dispatching tasks
---@field max_agents number Maximum concurrent agents
---@field auto_reload boolean Auto-reload files when status changes
---@field notify_on_complete boolean Show notification when task completes
---@field stuck_threshold number Iterations with same error before marking stuck

local M = {}

---@type ChiefWiggumConfig
M.defaults = {
  -- Where all chief-wiggum data lives
  -- Use "~/.chief-wiggum" for global, "./.wiggum" for per-project
  vault_path = vim.fn.expand("~/.chief-wiggum"),

  -- Subdirectories within the vault
  status_dir = "status",
  templates_dir = "templates",

  -- Command to spawn Claude in a new terminal
  -- %s placeholders: 1) task name (for window title), 2) task ID
  -- Uses tmux by default. For kitty: "kitty @ new-window --title '%s' bash -c 'CHIEF_WIGGUM_TASK_ID=%s claude'"
  dispatch_cmd = "tmux new-window -n '%s' 'CHIEF_WIGGUM_TASK_ID=%s CHIEF_WIGGUM_VAULT=%s claude'",

  -- Maximum number of concurrent agents
  -- Prevents runaway resource usage
  max_agents = 5,

  -- Automatically reload buffers when status files change
  -- Requires vim.uv (Neovim 0.10+)
  auto_reload = true,

  -- Show macOS notification when task completes or gets stuck
  notify_on_complete = true,

  -- Number of iterations with identical errors before marking as stuck
  stuck_threshold = 3,

  -- Keymaps (set to false to disable)
  keymaps = {
    status = "<leader>ws",     -- Show status window
    dispatch = "<leader>wd",   -- Dispatch current file
    command = "<leader>wc",    -- Open COMMAND.md
    recon = "<leader>wr",      -- Run recon scan
    queue = "<leader>wq",      -- Open QUEUE.md
  },
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
