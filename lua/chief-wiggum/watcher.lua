---File system watcher for status directory changes
---Uses vim.uv/vim.loop (libuv bindings) to watch for file changes
---and trigger buffer reloads

local M = {}

-- Use vim.uv (0.10+) or vim.loop (0.9+)
local uv = vim.uv or vim.loop

---@type uv_fs_event_t|nil
local watcher = nil

---@type table<string, number> Debounce timers by path
local debounce_timers = {}

---Debounce interval in milliseconds
local DEBOUNCE_MS = 100

---Start watching the status directory
---@param config ChiefWiggumConfig
function M.setup(config)
  -- Ensure we have libuv bindings
  if not uv then
    vim.notify(
      "[chief-wiggum] vim.uv/vim.loop not available. File watching disabled.",
      vim.log.levels.WARN
    )
    return
  end

  -- Only watch if vault exists (user must run :ChiefWiggumInit first)
  local vault_path = vim.fn.expand(config.vault_path)
  if vim.fn.isdirectory(vault_path) == 0 then
    return -- Vault not initialized, skip watching
  end

  local status_path = vault_path .. "/" .. config.status_dir

  -- Create status subdir if vault exists but status dir doesn't
  if vim.fn.isdirectory(status_path) == 0 then
    vim.fn.mkdir(status_path, "p")
  end

  -- Stop existing watcher if any
  M.stop()

  -- Create new watcher
  watcher = uv.new_fs_event()
  if not watcher then
    vim.notify("[chief-wiggum] Failed to create file watcher", vim.log.levels.ERROR)
    return
  end

  -- Start watching
  local ok, err = watcher:start(status_path, {}, function(err, filename, events)
    if err then
      vim.schedule(function()
        vim.notify("[chief-wiggum] Watch error: " .. err, vim.log.levels.ERROR)
      end)
      return
    end

    -- Debounce rapid changes
    local key = filename or "unknown"
    if debounce_timers[key] then
      return
    end

    debounce_timers[key] = vim.defer_fn(function()
      debounce_timers[key] = nil
      M.on_change(config, filename, events)
    end, DEBOUNCE_MS)
  end)

  if not ok then
    vim.notify("[chief-wiggum] Failed to start watcher: " .. (err or "unknown"), vim.log.levels.ERROR)
    return
  end

  vim.notify("[chief-wiggum] Watching " .. status_path, vim.log.levels.DEBUG)
end

---Handle file change event
---@param config ChiefWiggumConfig
---@param filename string|nil Changed filename
---@param events table Event details
function M.on_change(config, filename, events)
  vim.schedule(function()
    -- Trigger buffer reload for any open chief-wiggum files
    vim.cmd("checktime")

    -- If we have a status window open, refresh it
    local status = require("chief-wiggum.status")
    if status.is_open() then
      status.refresh()
    end

    -- Parse status file to check for completion/stuck
    if filename and filename:match("%.json$") then
      local status_path = config.vault_path .. "/" .. config.status_dir .. "/" .. filename
      M.check_status_update(config, status_path)
    end
  end)
end

---Check if a status update requires notification
---@param config ChiefWiggumConfig
---@param status_path string Path to status file
function M.check_status_update(config, status_path)
  local file = io.open(status_path, "r")
  if not file then
    return
  end

  local content = file:read("*a")
  file:close()

  local ok, data = pcall(vim.json.decode, content)
  if not ok or not data then
    return
  end

  -- Notify on completion or stuck
  if config.notify_on_complete then
    if data.status == "completed" then
      vim.notify(
        string.format("[chief-wiggum] Task '%s' completed!", data.task),
        vim.log.levels.INFO
      )
      -- Also trigger system notification
      M.system_notify(config, data.task, "completed")
    elseif data.status == "stuck" then
      vim.notify(
        string.format("[chief-wiggum] Task '%s' is stuck after %d iterations", data.task, data.iteration),
        vim.log.levels.WARN
      )
      M.system_notify(config, data.task, "stuck")
    elseif data.status == "needs_input" then
      vim.notify(
        string.format("[chief-wiggum] Task '%s' needs your input", data.task),
        vim.log.levels.WARN
      )
      M.system_notify(config, data.task, "needs_input")
    end
  end
end

---Send system notification (macOS)
---@param config ChiefWiggumConfig
---@param task_name string
---@param status string
function M.system_notify(config, task_name, status)
  local messages = {
    completed = "Task completed successfully",
    stuck = "Task is stuck and needs help",
    needs_input = "Task needs your input",
  }

  local msg = messages[status] or status
  local title = "Chief Wiggum: " .. task_name

  -- Platform-specific notifications
  if vim.fn.has("mac") == 1 then
    -- macOS: use osascript
    -- Escape quotes for AppleScript
    local safe_msg = msg:gsub('\\', '\\\\'):gsub('"', '\\"')
    local safe_title = title:gsub('\\', '\\\\'):gsub('"', '\\"')
    local cmd = string.format(
      [[osascript -e 'display notification "%s" with title "%s"']],
      safe_msg,
      safe_title
    )
    vim.fn.jobstart(cmd, { detach = true })
  elseif vim.fn.has("unix") == 1 and vim.fn.executable("notify-send") == 1 then
    -- Linux: use notify-send
    local urgency = (status == "stuck" or status == "needs_input") and "critical" or "normal"
    local cmd = string.format(
      "notify-send --urgency=%s %s %s",
      urgency,
      vim.fn.shellescape(title),
      vim.fn.shellescape(msg)
    )
    vim.fn.jobstart(cmd, { detach = true })
  end
  -- Other platforms: silent fallback
end

---Stop the file watcher
function M.stop()
  if watcher then
    watcher:stop()
    watcher = nil
  end

  -- Clear any pending debounce timers
  for key, _ in pairs(debounce_timers) do
    debounce_timers[key] = nil
  end
end

return M
