---Task dispatching module
---Spawns Claude Code sessions with task context

local M = {}

---Extract task ID from file path
---@param file_path string
---@return string
local function get_task_id(file_path)
  -- Extract filename without extension
  local filename = vim.fn.fnamemodify(file_path, ":t:r")
  -- Sanitize for use as identifier
  return filename:gsub("[^%w%-_]", "-")
end

---Read and validate a task file
---@param file_path string
---@return table|nil task Task data or nil if invalid
---@return string|nil error Error message if invalid
local function read_task_file(file_path)
  local file = io.open(file_path, "r")
  if not file then
    return nil, "Cannot read file: " .. file_path
  end

  local content = file:read("*a")
  file:close()

  -- Extract key sections
  local task = {
    path = file_path,
    id = get_task_id(file_path),
    name = content:match("^#%s*(.-)%s*\n") or get_task_id(file_path),
    type = content:match("## Type%s*\n<!%-%- .-%-%->%s*\n(%w+)"),
    objective = content:match("## Objective%s*\n<!%-%- .-%-%->%s*\n(.-)%s*\n\n"),
    verification = content:match("```bash\n(.-)\n```"),
    max_iterations = tonumber(content:match("## Max Iterations%s*\n(%d+)")) or 20,
    prompt = content:match("## Prompt%s*\n````\n(.-)````"),
  }

  -- Validation
  if not task.verification then
    return nil, "Task missing verification command. Cannot dispatch without verifiable completion criteria."
  end

  if not task.verification:match("DONE") then
    return nil, "Verification command must output 'DONE' on success. Add '&& echo \"DONE\"' to your command."
  end

  return task, nil
end

---Get count of currently running agents
---@param config ChiefWiggumConfig
---@return number
local function count_running_agents(config)
  local status_path = config.vault_path .. "/" .. config.status_dir
  local count = 0

  local handle = vim.uv.fs_scandir(status_path)
  if not handle then
    return 0
  end

  while true do
    local name, type = vim.uv.fs_scandir_next(handle)
    if not name then
      break
    end

    if type == "file" and name:match("%.json$") then
      local file = io.open(status_path .. "/" .. name, "r")
      if file then
        local content = file:read("*a")
        file:close()
        local ok, data = pcall(vim.json.decode, content)
        if ok and data and data.status == "running" then
          count = count + 1
        end
      end
    end
  end

  return count
end

---Initialize status file for a task
---@param config ChiefWiggumConfig
---@param task table
local function init_status_file(config, task)
  local status_path = config.vault_path .. "/" .. config.status_dir
  vim.fn.mkdir(status_path, "p")

  local status = {
    task = task.id,
    name = task.name,
    path = task.path,
    status = "running",
    iteration = 0,
    max_iterations = task.max_iterations,
    iterations_history = {},
    started_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    last_update = os.date("!%Y-%m-%dT%H:%M:%SZ"),
  }

  local file = io.open(status_path .. "/" .. task.id .. ".json", "w")
  if file then
    file:write(vim.json.encode(status))
    file:close()
  end
end

---Dispatch a task to Claude Code
---@param file_path string|nil Path to task file (defaults to current file)
---@param config ChiefWiggumConfig
function M.dispatch(file_path, config)
  -- Default to current file
  file_path = file_path or vim.fn.expand("%:p")

  if file_path == "" then
    vim.notify("[chief-wiggum] No file specified", vim.log.levels.ERROR)
    return
  end

  -- Check if file exists
  if vim.fn.filereadable(file_path) == 0 then
    vim.notify("[chief-wiggum] File not found: " .. file_path, vim.log.levels.ERROR)
    return
  end

  -- Read and validate task
  local task, err = read_task_file(file_path)
  if not task then
    vim.notify("[chief-wiggum] " .. err, vim.log.levels.ERROR)
    return
  end

  -- Check agent limit
  local running = count_running_agents(config)
  if running >= config.max_agents then
    vim.notify(
      string.format(
        "[chief-wiggum] Max agents reached (%d/%d). Wait for tasks to complete or increase max_agents.",
        running,
        config.max_agents
      ),
      vim.log.levels.ERROR
    )
    return
  end

  -- Initialize status file
  init_status_file(config, task)

  -- Build dispatch command
  local cmd = string.format(
    config.dispatch_cmd,
    task.name,
    task.id,
    config.vault_path
  )

  -- Add initial prompt if available
  if task.prompt then
    -- Write prompt to a temp file that Claude can read
    local prompt_file = config.vault_path .. "/prompts/" .. task.id .. ".md"
    vim.fn.mkdir(config.vault_path .. "/prompts", "p")
    local pf = io.open(prompt_file, "w")
    if pf then
      pf:write(task.prompt)
      pf:close()
    end
  end

  -- Execute dispatch
  vim.fn.jobstart(cmd, {
    detach = true,
    on_exit = function(_, code)
      if code ~= 0 then
        vim.schedule(function()
          vim.notify(
            "[chief-wiggum] Failed to dispatch task. Check tmux is running.",
            vim.log.levels.ERROR
          )
        end)
      end
    end,
  })

  vim.notify(
    string.format("[chief-wiggum] Dispatched '%s' (agent %d/%d)", task.name, running + 1, config.max_agents),
    vim.log.levels.INFO
  )
end

---Run recon scan on the codebase
---@param config ChiefWiggumConfig
---@param scope string|nil Directory or pattern to scan
function M.recon(config, scope)
  scope = scope or "."

  -- Create recon task
  local task_id = "recon-" .. os.date("%Y%m%d-%H%M%S")
  local task = {
    id = task_id,
    name = "Recon: " .. scope,
    path = config.vault_path .. "/tasks/" .. task_id .. ".md",
    max_iterations = 1, -- Recon is single-shot
  }

  -- Initialize status
  init_status_file(config, task)

  -- Build command with recon slash command
  local cmd = string.format(
    config.dispatch_cmd,
    task.name,
    task.id,
    config.vault_path
  )
  -- The Claude session will need to run /chief-wiggum:recon

  vim.fn.jobstart(cmd, { detach = true })

  vim.notify(
    string.format("[chief-wiggum] Started recon scan on '%s'", scope),
    vim.log.levels.INFO
  )
end

---Dispatch the current file if it's a task
function M.dispatch_current()
  local file = vim.fn.expand("%:p")
  local config = require("chief-wiggum.config").get()

  -- Check if it looks like a task file
  if not (file:match("/features/") or file:match("/tasks/") or file:match("%.task%.md$")) then
    vim.notify(
      "[chief-wiggum] Current file doesn't appear to be a task. Use :ChiefWiggumDispatch <path>",
      vim.log.levels.WARN
    )
    return
  end

  M.dispatch(file, config)
end

return M
