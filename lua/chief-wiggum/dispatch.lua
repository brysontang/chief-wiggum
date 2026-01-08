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
    local key, value = line:match("^([%w_-]+):%s*(.+)$")
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

      local fm = parse_frontmatter(content)

      -- Frontmatter overrides defaults (but config overrides frontmatter)
      if fm.tool and not (config.agent_tool and config.agent_tool[agent_name]) then
        agent.tool = fm.tool
      end
      if fm.model then
        agent.model = fm.model
      end
      if fm.description then
        agent.description = fm.description
      end
    end
  end

  return agent
end

---Extract task ID from file path (sanitized for shell safety)
---@param file_path string
---@return string
local function get_task_id(file_path)
  local filename = vim.fn.fnamemodify(file_path, ":t:r")
  -- Only allow alphanumeric, dash, underscore
  return filename:gsub("[^%w%-_]", "-"):gsub("%-+", "-")
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

  -- Parse worktree path (only capture content on the same line)
  -- Use [ \t]* instead of %s* because %s matches newlines in Lua
  local raw_path = content:match("Path:[ \t]*([^\n]*)")
  if raw_path then
    raw_path = raw_path:match("^[ \t]*(.-)[ \t]*$") -- trim spaces/tabs only
    if raw_path == "" then raw_path = nil end
  end

  local raw_branch = content:match("Branch:[ \t]*([^\n]*)")
  if raw_branch then
    raw_branch = raw_branch:match("^[ \t]*(.-)[ \t]*$")
    if raw_branch == "" then raw_branch = nil end
  end

  local task = {
    path = file_path,
    id = get_task_id(file_path),
    name = content:match("^#%s*(.-)%s*\n") or get_task_id(file_path),
    objective = content:match("## Objective%s*\n.-\n(.-)%s*\n\n"),
    max_iterations = tonumber(content:match("Max Iterations%s*\n(%d+)")) or 20,
    worktree_path = raw_path,
    worktree_branch = raw_branch,
  }

  -- Sanitize task name for shell safety
  task.name = task.name:gsub("[^%w%s%-_]", ""):sub(1, 50)

  return task, nil
end

---Get count of currently running agents
---@param config ChiefWiggumConfig
---@return number
local function count_running_agents(config)
  local status_path = config.vault_path .. "/" .. config.status_dir
  local count = 0

  -- Use vim.uv if available (0.10+), fall back to vim.loop (0.9+)
  local uv = vim.uv or vim.loop
  if not uv then
    return 0
  end

  local handle = uv.fs_scandir(status_path)
  if not handle then
    return 0
  end

  while true do
    local name, type = uv.fs_scandir_next(handle)
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
  -- Only write status if vault exists (user must run :ChiefWiggumInit first)
  local vault_path = vim.fn.expand(config.vault_path)
  if vim.fn.isdirectory(vault_path) == 0 then
    return -- Vault not initialized, skip status tracking
  end

  local status_path = vault_path .. "/" .. config.status_dir
  vim.fn.mkdir(status_path, "p") -- OK to create status subdir if vault exists

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

---Build the prompt that tells Claude to spawn a subagent
---@param task table Task data
---@param stage_name string Stage to work on
---@param agent table Agent configuration
---@return string prompt
local function build_subagent_prompt(task, stage_name, agent)
  -- Agent name is used as-is (e.g., "chief-wiggum:implement", "my-plugin:custom")
  local agent_ref = agent.name
  return string.format([[
Spawn the %s subagent to complete the %s stage.

Task file: %s

The subagent should:
1. Read the task file completely
2. Find the current active stage (marked with ← ACTIVE)
3. Read the ## Log section to understand what previous iterations did
4. Do the work required for this stage
5. Run the verification command if one exists
6. Append progress to the ## Log section

When the subagent reports completion:
1. Update the task file to advance the stage marker:
   - Remove "← ACTIVE" from the current stage header
   - Add "← ACTIVE" to the next stage header
2. Then output exactly: ###CHIEF_WIGGUM_DONE###
   followed by a brief summary of what was accomplished.

When the subagent reports being stuck:
1. Output exactly: ###CHIEF_WIGGUM_STUCK###
   followed by the reason from the subagent.

IMPORTANT: Use these exact markers. They are used for automated status detection.
The stage marker MUST be moved before outputting DONE so the next dispatch knows which stage to run.
]], agent_ref, stage_name, task.path)
end

---Substitute named placeholders in a template string
---@param template string Template with {placeholder} markers
---@param values table<string, string> Map of placeholder names to values
---@return string result Template with placeholders replaced
local function substitute_template(template, values)
  local result = template
  for key, value in pairs(values) do
    -- Escape the value for shell safety
    local escaped = vim.fn.shellescape(value)
    result = result:gsub("{" .. key .. "}", escaped)
  end
  return result
end

---Build dispatch command with proper escaping
---@param task table Task data
---@param stage_name string Stage name
---@param agent table Agent config
---@param config ChiefWiggumConfig
---@param worktree_path string Working directory
---@return string|nil cmd Command to execute
---@return string|nil err Error message
local function build_dispatch_command(task, stage_name, agent, config, worktree_path)
  local tool = agent.tool or "claude"

  -- Check if tmux is available
  local tmux_check = vim.fn.system("command -v tmux")
  if vim.v.shell_error ~= 0 then
    return nil, "tmux not found. Install tmux or dispatch manually."
  end

  -- Only Claude is supported
  if tool ~= "claude" then
    return nil, string.format("Tool '%s' not supported. Only 'claude' is supported.", tool)
  end

  -- Build the prompt that spawns the subagent
  local prompt = build_subagent_prompt(task, stage_name, agent)

  -- Max turns for cost control
  local max_turns = config.max_turns or 20

  -- Build Claude command with:
  -- --max-turns: cost control
  -- --allowedTools: auto-approve common tools
  -- Environment vars for hooks
  -- Interactive mode so user can observe Claude working
  local allowed_tools = config.allowed_tools or "Edit,Write,Read,Bash,Glob,Grep"
  local inner_cmd = string.format(
    "cd %s && CHIEF_WIGGUM_TASK_ID=%s CHIEF_WIGGUM_VAULT=%s CHIEF_WIGGUM_STUCK_THRESHOLD=%d claude --max-turns %d --allowedTools %s %s",
    vim.fn.shellescape(worktree_path),
    vim.fn.shellescape(task.id),
    vim.fn.shellescape(config.vault_path),
    config.stuck_threshold or 3,
    max_turns,
    vim.fn.shellescape(allowed_tools),
    vim.fn.shellescape(prompt)
  )

  local cmd = string.format(
    "tmux new-window -n %s %s",
    vim.fn.shellescape(task.name:sub(1, 20)),
    vim.fn.shellescape(inner_cmd)
  )

  return cmd, nil
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
    local ok, stages = pcall(require, "chief-wiggum.stages")
    if ok then
      local current = stages.current_stage()
      if current then
        stage_name = current.name
        if not agent_name then
          agent_name = current.agent
        end
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
    local ok, worktree = pcall(require, "chief-wiggum.worktree")
    if ok then
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
    else
      worktree_path = vim.fn.getcwd()
    end
  end

  worktree_path = worktree_path or vim.fn.getcwd()

  -- Initialize status
  init_status_file(config, task, stage_name, agent_name)

  -- Build dispatch command
  local cmd, cmd_err = build_dispatch_command(task, stage_name, agent, config, worktree_path)
  if not cmd then
    vim.notify("[chief-wiggum] " .. cmd_err, vim.log.levels.ERROR)
    return
  end

  -- Execute dispatch
  local job_id = vim.fn.jobstart(cmd, {
    detach = true,
    on_exit = function(_, code)
      if code ~= 0 and code ~= 2 then
        vim.schedule(function()
          vim.notify(
            string.format("[chief-wiggum] Dispatch may have failed (code %d). Check tmux.", code),
            vim.log.levels.WARN
          )
        end)
      end
    end,
  })

  if job_id <= 0 then
    vim.notify("[chief-wiggum] Failed to start dispatch job. Is tmux installed?", vim.log.levels.ERROR)
    return
  end

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
  local ok, stages = pcall(require, "chief-wiggum.stages")
  local stage, agent = nil, nil
  if ok then
    stage = stages.current_stage()
    agent = stages.current_agent()
  end

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
    name = "Recon " .. scope:sub(1, 20),
    path = config.vault_path .. "/tasks/RECON.md",
    max_iterations = 1,
  }

  init_status_file(config, task, "RESEARCH", "recon")

  -- Check tmux
  local tmux_check = vim.fn.system("command -v tmux")
  if vim.v.shell_error ~= 0 then
    vim.notify("[chief-wiggum] tmux not found", vim.log.levels.ERROR)
    return
  end

  local prompt = string.format([[
Scan the codebase at %s and identify actionable improvements.

Output format for each finding:
- [ ] [category:confidence:effort] Description — `path/to/file`

Categories: bug, security, performance, test, debt, refactor
Confidence: high, medium, low
Effort: small, medium, large

Only report findings that can have verification commands.
Write findings to: %s/tasks/RECON.md

Begin scanning now.
]], scope, config.vault_path)

  local inner_cmd = string.format(
    "cd %s && CHIEF_WIGGUM_TASK_ID=%s CHIEF_WIGGUM_VAULT=%s claude %s",
    vim.fn.shellescape(vim.fn.getcwd()),
    vim.fn.shellescape(task_id),
    vim.fn.shellescape(config.vault_path),
    vim.fn.shellescape(prompt)
  )

  local cmd = string.format(
    "tmux new-window -n %s %s",
    vim.fn.shellescape("recon"),
    vim.fn.shellescape(inner_cmd)
  )

  local job_id = vim.fn.jobstart(cmd, { detach = true })

  if job_id <= 0 then
    vim.notify("[chief-wiggum] Failed to start recon", vim.log.levels.ERROR)
    return
  end

  vim.notify("[chief-wiggum] Started recon scan on '" .. scope .. "'", vim.log.levels.INFO)
end

return M
