---Git worktree management for task isolation
---Each task gets its own worktree for true parallel development

local M = {}

---Get the git root directory
---@return string|nil
local function get_git_root()
  local result = vim.fn.system("git rev-parse --show-toplevel 2>/dev/null")
  if vim.v.shell_error ~= 0 then
    return nil
  end
  return vim.fn.trim(result)
end

---Create a worktree for a task
---@param task_id string Task identifier
---@param branch_name string|nil Branch name (defaults to feature/<task_id>)
---@return string|nil worktree_path Path to created worktree
---@return string|nil error Error message if failed
function M.create(task_id, branch_name)
  local config = require("chief-wiggum.config").get()
  local git_root = get_git_root()

  if not git_root then
    return nil, "Not in a git repository"
  end

  local worktree_base = config.worktree_base
  -- Make absolute if relative
  if not worktree_base:match("^/") then
    worktree_base = git_root .. "/" .. worktree_base
  end

  local worktree_path = worktree_base .. "/" .. task_id
  branch_name = branch_name or ("feature/" .. task_id)

  -- Ensure base directory exists
  vim.fn.mkdir(worktree_base, "p")

  -- Check if worktree already exists
  if vim.fn.isdirectory(worktree_path) == 1 then
    return worktree_path, nil -- Already exists, return it
  end

  -- Check if branch exists
  local branch_exists = vim.fn.system(
    string.format("git show-ref --verify --quiet refs/heads/%s 2>/dev/null && echo yes || echo no", branch_name)
  )
  branch_exists = vim.fn.trim(branch_exists) == "yes"

  local cmd
  if branch_exists then
    -- Use existing branch
    cmd = string.format(
      "git worktree add %s %s 2>&1",
      vim.fn.shellescape(worktree_path),
      vim.fn.shellescape(branch_name)
    )
  else
    -- Create new branch from current HEAD
    cmd = string.format(
      "git worktree add -b %s %s 2>&1",
      vim.fn.shellescape(branch_name),
      vim.fn.shellescape(worktree_path)
    )
  end

  local result = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    return nil, "Failed to create worktree: " .. result
  end

  return worktree_path, nil
end

---Remove a worktree
---@param task_id string Task identifier
---@param force boolean|nil Force removal even if dirty
---@return boolean success
---@return string|nil error
function M.remove(task_id, force)
  local config = require("chief-wiggum.config").get()
  local git_root = get_git_root()

  if not git_root then
    return false, "Not in a git repository"
  end

  local worktree_base = config.worktree_base
  if not worktree_base:match("^/") then
    worktree_base = git_root .. "/" .. worktree_base
  end

  local worktree_path = worktree_base .. "/" .. task_id

  local cmd = force
      and string.format("git worktree remove --force %s 2>&1", vim.fn.shellescape(worktree_path))
      or string.format("git worktree remove %s 2>&1", vim.fn.shellescape(worktree_path))

  local result = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    return false, result
  end

  return true, nil
end

---List all worktrees with status
---@return table[] worktrees Array of worktree info objects
function M.list()
  local output = vim.fn.system("git worktree list --porcelain 2>/dev/null")
  if vim.v.shell_error ~= 0 then
    return {}
  end

  local worktrees = {}
  local current = {}

  for line in output:gmatch("[^\n]+") do
    if line:match("^worktree ") then
      if current.path then
        table.insert(worktrees, current)
      end
      current = { path = line:match("^worktree (.+)") }
    elseif line:match("^HEAD ") then
      current.head = line:match("^HEAD (.+)")
    elseif line:match("^branch ") then
      current.branch = line:match("^branch refs/heads/(.+)")
    elseif line:match("^detached") then
      current.detached = true
    elseif line:match("^bare") then
      current.bare = true
    end
  end

  if current.path then
    table.insert(worktrees, current)
  end

  return worktrees
end

---Get worktree for a task ID
---@param task_id string
---@return table|nil worktree
function M.get(task_id)
  local config = require("chief-wiggum.config").get()
  local git_root = get_git_root()

  if not git_root then
    return nil
  end

  local worktree_base = config.worktree_base
  if not worktree_base:match("^/") then
    worktree_base = git_root .. "/" .. worktree_base
  end

  local worktree_path = worktree_base .. "/" .. task_id

  local worktrees = M.list()
  for _, wt in ipairs(worktrees) do
    if wt.path == worktree_path then
      wt.task_id = task_id
      return wt
    end
  end

  return nil
end

---Check how many commits a worktree is behind main
---@param task_id string Task identifier
---@return number behind Number of commits behind
---@return number ahead Number of commits ahead
function M.staleness(task_id)
  local config = require("chief-wiggum.config").get()
  local git_root = get_git_root()

  if not git_root then
    return 0, 0
  end

  local worktree_base = config.worktree_base
  if not worktree_base:match("^/") then
    worktree_base = git_root .. "/" .. worktree_base
  end

  local worktree_path = worktree_base .. "/" .. task_id

  if vim.fn.isdirectory(worktree_path) == 0 then
    return 0, 0
  end

  -- Fetch latest
  vim.fn.system(string.format("git -C %s fetch origin main 2>/dev/null", vim.fn.shellescape(worktree_path)))

  -- Count commits behind
  local behind = vim.fn.system(string.format(
    "git -C %s rev-list --count HEAD..origin/main 2>/dev/null",
    vim.fn.shellescape(worktree_path)
  ))
  behind = tonumber(vim.fn.trim(behind)) or 0

  -- Count commits ahead
  local ahead = vim.fn.system(string.format(
    "git -C %s rev-list --count origin/main..HEAD 2>/dev/null",
    vim.fn.shellescape(worktree_path)
  ))
  ahead = tonumber(vim.fn.trim(ahead)) or 0

  return behind, ahead
end

---Check if worktree has uncommitted changes
---@param task_id string
---@return boolean dirty
function M.is_dirty(task_id)
  local config = require("chief-wiggum.config").get()
  local git_root = get_git_root()

  if not git_root then
    return false
  end

  local worktree_base = config.worktree_base
  if not worktree_base:match("^/") then
    worktree_base = git_root .. "/" .. worktree_base
  end

  local worktree_path = worktree_base .. "/" .. task_id

  local status = vim.fn.system(string.format(
    "git -C %s status --porcelain 2>/dev/null",
    vim.fn.shellescape(worktree_path)
  ))

  return vim.fn.trim(status) ~= ""
end

---Open worktree in file explorer or change cwd
---@param task_id string
---@param method string|nil "netrw"|"neo-tree"|"oil"|"cd"
function M.open(task_id, method)
  local config = require("chief-wiggum.config").get()
  local git_root = get_git_root()

  if not git_root then
    vim.notify("[chief-wiggum] Not in a git repository", vim.log.levels.ERROR)
    return
  end

  local worktree_base = config.worktree_base
  if not worktree_base:match("^/") then
    worktree_base = git_root .. "/" .. worktree_base
  end

  local worktree_path = worktree_base .. "/" .. task_id

  if vim.fn.isdirectory(worktree_path) == 0 then
    vim.notify("[chief-wiggum] Worktree does not exist: " .. task_id, vim.log.levels.ERROR)
    return
  end

  method = method or "netrw"

  if method == "cd" then
    vim.cmd("cd " .. vim.fn.fnameescape(worktree_path))
    vim.notify("[chief-wiggum] Changed to " .. worktree_path, vim.log.levels.INFO)
  elseif method == "neo-tree" then
    vim.cmd("Neotree " .. vim.fn.fnameescape(worktree_path))
  elseif method == "oil" then
    vim.cmd("Oil " .. vim.fn.fnameescape(worktree_path))
  else
    vim.cmd("Explore " .. vim.fn.fnameescape(worktree_path))
  end
end

---Prune worktrees that no longer have task files
function M.prune_orphaned()
  local config = require("chief-wiggum.config").get()
  local vault = config.vault_path
  local worktrees = M.list()
  local pruned = 0

  for _, wt in ipairs(worktrees) do
    -- Skip main worktree
    if wt.bare then
      goto continue
    end

    -- Extract task_id from path
    local task_id = wt.path:match("/([^/]+)$")
    if task_id then
      -- Check if task file exists
      local task_file = vault .. "/tasks/features/" .. task_id .. ".md"
      if vim.fn.filereadable(task_file) == 0 then
        local ok, err = M.remove(task_id, false)
        if ok then
          pruned = pruned + 1
        end
      end
    end

    ::continue::
  end

  if pruned > 0 then
    vim.notify(string.format("[chief-wiggum] Pruned %d orphaned worktrees", pruned), vim.log.levels.INFO)
  end

  return pruned
end

return M
