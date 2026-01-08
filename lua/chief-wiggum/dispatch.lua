---Task dispatching module
---Spawns agents with fresh context into worktrees

local M = {}

---Parse YAML frontmatter from markdown content
---@param content string File content
---@return table frontmatter Parsed frontmatter fields
local function parse_frontmatter(content)
  local frontmatter = {}

  -- Check for --- delimited frontmatter
  local fm_start, fm_end = content:find("^%-%-%-\n")
  if not fm_start then
    return frontmatter
  end

  local _, content_start = content:find("\n%-%-%-\n", fm_end)
  if not content_start then
    return frontmatter
  end

  local fm_text = content:sub(fm_end + 1, content_start - 4)

  -- Simple YAML parsing for key: value pairs
  for line in fm_text:gmatch("[^\n]+") do
    local key, value = line:match("^(%w+):%s*(.+)$")
    if key and value then
      frontmatter[key] = value
    end
  end

  return frontmatter
end

---Parse agent file and extract configuration
---@param agent_name string Agent name
---@param config ChiefWiggumConfig
---@return table agent {name, tool, model, description}
local function parse_agent_file(agent_name, config)
  local agent = {
    name = agent_name,
    tool = "claude",
    model = nil,
    description = "",
  }

  -- Check config override first
  if config.agent_tool and config.agent_tool[agent_name] then
    agent.tool = config.agent_tool[agent_name]
  end

  -- Try user agents in vault
  local user_agent_path = config.vault_path .. "/agents/" .. agent_name .. ".md"
  local agent_path = user_agent_path

  if vim.fn.filereadable(agent_path) == 0 then
    -- Fall back to bundled agents
    local source = debug.getinfo(1, "S").source:sub(2)
    local plugin_root = vim.fn.fnamemodify(source, ":h:h:h")
    agent_path = plugin_root .. "/agents/" .. agent_name .. ".md"
  end

  if vim.fn.filereadable(agent_path) == 1 then
    local file = io.open(agent_path, "r")
    if file then
      local content = file:read("*a")
      file:close()

      local frontmatter = parse_frontmatter(content)

      -- Frontmatter overrides defaults (but config overrides frontmatter)
      if frontmatter.tool and not (config.agent_tool and config.agent_tool[agent_name]) then
        agent.tool = frontmatter.tool
      end
      if frontmatter.model then
        agent.model = frontmatter.model
      end
      if frontmatter.description then
        agent.description = frontmatter.description
      end
    end
  end

  return agent
end

---Extract task ID from file path
---@param file_path string
---@return string
local function get_task_id(file_path)
  local filename = vim.fn.fnamemodify(file_path, ":t:r")
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

  local task = {
    path = file_path,
    id = get_task_id(file_path),
    name = content:match("^#%s*(.-)%s*\n") or get_task_id(file_path),
    objective = content:match("## Objective%s*\n.-\n(.-)%s*\n\n"),
    max_iterations = tonumber(content:match("Max Iterations%s*\n(%d+)")) or 20,
    worktree_path = content:match("Path:%s*(.-)%s*\n"),
    worktree_branch = content:match("Branch:%s*(.-)%s*\n"),
  }

  return task, nil
end

---Get count of currently running agents
---@param config ChiefWiggumConfig
---@return number
local function count_running_agents(config)
  local status_path = config.vault_path .. "/" .. config.status_dir
  local count = 0

  if not vim.uv then
    return 0
  end

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
      local f = io.open(status_path .. "/" .. name, "r")
      if f then
        local data = f:read("*a")
        f:close()
        local ok, status = pcall(vim.json.decode, data)
        if ok and status and status.status == "running" then
          count = count + 1
        end
      end
    end
  end

  return count
end

---Initialize or update status file for a task
---@param config ChiefWiggumConfig
---@param task table
---@param stage_name string|nil
---@param agent_name string|nil
local function init_status_file(config, task, stage_name, agent_name)
  local status_path = config.vault_path .. "/" .. config.status_dir
  vim.fn.mkdir(status_path, "p")

  local status_file = status_path .. "/" .. task.id .. ".json"
  local existing = nil

  -- Read existing status if present
  if vim.fn.filereadable(status_file) == 1 then
    local f = io.open(status_file, "r")
    if f then
      local data = f:read("*a")
      f:close()
      local ok, parsed = pcall(vim.json.decode, data)
      if ok then
        existing = parsed
      end
    end
  end

  local status = existing or {
    task = task.id,
    name = task.name,
    path = task.path,
    iteration = 0,
    max_iterations = task.max_iterations,
    iterations_history = {},
    started_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
  }

  -- Update with current dispatch info
  status.status = "running"
  status.stage = stage_name
  status.agent = agent_name
  status.worktree = task.worktree_path
  status.last_update = os.date("!%Y-%m-%dT%H:%M:%SZ")

  local f = io.open(status_file, "w")
  if f then
    f:write(vim.json.encode(status))
    f:close()
  end
end

---Update worktree info in task file
---@param task_path string
---@param worktree_path string
---@param branch_name string
local function update_task_worktree(task_path, worktree_path, branch_name)
  local file = io.open(task_path, "r")
  if not file then
    return
  end

  local content = file:read("*a")
  file:close()

  -- Update Path: and Branch: fields
  content = content:gsub("(Path:%s*).-\n", "%1" .. worktree_path .. "\n")
  content = content:gsub("(Branch:%s*).-\n", "%1" .. branch_name .. "\n")

  file = io.open(task_path, "w")
  if file then
    file:write(content)
    file:close()
  end
end

---Write prompt file for the agent
---@param config ChiefWiggumConfig
---@param task table
---@param stage_name string
---@param agent table
---@return string prompt_path
local function write_prompt_file(config, task, stage_name, agent)
  local prompt_dir = config.vault_path .. "/prompts"
  vim.fn.mkdir(prompt_dir, "p")

  local prompt_path = prompt_dir .. "/" .. task.id .. "-" .. stage_name .. ".md"

  local prompt = string.format(
    [[
# Task: %s
# Stage: %s
# Agent: %s (%s)

Read the task file at: %s

Focus on the %s stage. The verification command for this stage is in the task file.

Remember: You have a fresh context. Read the ## Log section to see what previous iterations did.
State lives in files, not in conversation history.

When done, output: DONE
If stuck, output: STUCK: <reason>
]],
    task.name,
    stage_name,
    agent.name,
    agent.tool,
    task.path,
    stage_name
  )

  local f = io.open(prompt_path, "w")
  if f then
    f:write(prompt)
    f:close()
  end

  return prompt_path
end

---Dispatch a stage to the appropriate agent
---@param task_file string Path to task file
---@param stage_name string|nil Stage to dispatch (nil = current active)
---@param agent_name string|nil Agent to use (nil = stage default)
---@param config ChiefWiggumConfig
function M.dispatch_stage(task_file, stage_name, agent_name, config)
  -- Read task file
  local task, err = read_task_file(task_file)
  if not task then
    vim.notify("[chief-wiggum] " .. err, vim.log.levels.ERROR)
    return
  end

  -- Get stage info if not specified
  if not stage_name then
    local stages = require("chief-wiggum.stages")
    local current = stages.current_stage()
    if current then
      stage_name = current.name
      if not agent_name then
        agent_name = current.agent
      end
    end
  end

  stage_name = stage_name or "IMPLEMENT"

  -- Get agent if not specified
  if not agent_name then
    agent_name = config.agent_for_stage[stage_name] or config.default_agent
  end

  -- Check if human stage
  if agent_name == "human" then
    vim.notify(
      string.format("[chief-wiggum] %s stage requires human action", stage_name),
      vim.log.levels.INFO
    )
    return
  end

  -- Parse agent configuration
  local agent = parse_agent_file(agent_name, config)

  -- Get dispatch command for this tool
  local dispatch_template = config.dispatch_commands[agent.tool]
  if not dispatch_template then
    vim.notify(
      string.format("[chief-wiggum] Unknown tool '%s' for agent '%s'", agent.tool, agent_name),
      vim.log.levels.ERROR
    )
    return
  end

  -- Check agent limit
  local running = count_running_agents(config)
  if running >= config.max_agents then
    vim.notify(
      string.format(
        "[chief-wiggum] Max agents reached (%d/%d). Wait for tasks to complete.",
        running,
        config.max_agents
      ),
      vim.log.levels.ERROR
    )
    return
  end

  -- Create worktree if needed
  local worktree_path = task.worktree_path
  if config.auto_create_worktree and (not worktree_path or worktree_path == "") then
    local worktree = require("chief-wiggum.worktree")
    local wt_path, wt_err = worktree.create(task.id)
    if wt_err then
      vim.notify("[chief-wiggum] Worktree creation failed: " .. wt_err, vim.log.levels.WARN)
      -- Continue without worktree
      worktree_path = vim.fn.getcwd()
    else
      worktree_path = wt_path
      local branch = "feature/" .. task.id
      update_task_worktree(task_file, worktree_path, branch)
      task.worktree_path = worktree_path
    end
  end

  worktree_path = worktree_path or vim.fn.getcwd()

  -- Write prompt file
  local prompt_path = write_prompt_file(config, task, stage_name, agent)

  -- Initialize status
  init_status_file(config, task, stage_name, agent_name)

  -- Build dispatch command
  -- The template expects: task_name, worktree_path, task_id, vault_path, prompt_path, model
  local cmd = string.format(
    dispatch_template,
    task.name .. ":" .. stage_name,
    worktree_path,
    task.id,
    config.vault_path,
    prompt_path,
    agent.model or ""
  )

  -- Execute dispatch
  vim.fn.jobstart(cmd, {
    detach = true,
    on_exit = function(_, code)
      if code ~= 0 and code ~= 2 then
        vim.schedule(function()
          vim.notify(
            string.format("[chief-wiggum] Dispatch failed (code %d). Check tmux.", code),
            vim.log.levels.ERROR
          )
        end)
      end
    end,
  })

  vim.notify(
    string.format(
      "[chief-wiggum] Dispatched '%s' stage '%s' with agent '%s' (%s)",
      task.name,
      stage_name,
      agent_name,
      agent.tool
    ),
    vim.log.levels.INFO
  )
end

---Dispatch current file's current stage
function M.dispatch_current()
  local file = vim.fn.expand("%:p")
  local config = require("chief-wiggum.config").get()

  if not (file:match("/features/") or file:match("/tasks/") or file:match("%.task%.md$")) then
    vim.notify(
      "[chief-wiggum] Current file doesn't appear to be a task.",
      vim.log.levels.WARN
    )
    return
  end

  -- Get current stage info from buffer
  local stages = require("chief-wiggum.stages")
  local stage = stages.current_stage()
  local agent = stages.current_agent()

  M.dispatch_stage(file, stage and stage.name, agent, config)
end

---Legacy dispatch function (dispatches to IMPLEMENT stage)
---@param file_path string|nil Path to task file
---@param config ChiefWiggumConfig
function M.dispatch(file_path, config)
  file_path = file_path or vim.fn.expand("%:p")

  if file_path == "" then
    vim.notify("[chief-wiggum] No file specified", vim.log.levels.ERROR)
    return
  end

  M.dispatch_stage(file_path, nil, nil, config)
end

---Run recon scan
---@param config ChiefWiggumConfig
---@param scope string|nil
function M.recon(config, scope)
  scope = scope or "."

  local task_id = "recon-" .. os.date("%Y%m%d-%H%M%S")
  local task = {
    id = task_id,
    name = "Recon: " .. scope,
    path = config.vault_path .. "/tasks/" .. task_id .. ".md",
    max_iterations = 1,
  }

  init_status_file(config, task, "RESEARCH", "recon")

  local agent = parse_agent_file("recon", config)
  local dispatch_template = config.dispatch_commands[agent.tool]

  if dispatch_template then
    local cmd = string.format(
      dispatch_template,
      task.name,
      vim.fn.getcwd(),
      task.id,
      config.vault_path,
      "",
      ""
    )

    vim.fn.jobstart(cmd, { detach = true })
    vim.notify("[chief-wiggum] Started recon scan on '" .. scope .. "'", vim.log.levels.INFO)
  end
end

return M
