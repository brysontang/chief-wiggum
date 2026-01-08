---Status window module
---Displays a floating window with agent statuses

local M = {}

-- Use vim.uv (0.10+) or vim.loop (0.9+)
local uv = vim.uv or vim.loop

---@type number|nil Buffer handle for status window
local status_buf = nil

---@type number|nil Window handle for status window
local status_win = nil

---Check if status window is open
---@return boolean
function M.is_open()
  return status_win ~= nil and vim.api.nvim_win_is_valid(status_win)
end

---Close status window
function M.close()
  if status_win and vim.api.nvim_win_is_valid(status_win) then
    vim.api.nvim_win_close(status_win, true)
  end
  status_win = nil
  status_buf = nil
end

---Get status icon for a status string
---@param status string
---@return string
local function get_status_icon(status)
  local icons = {
    running = "●",
    completed = "✓",
    stuck = "✗",
    needs_input = "?",
    pending = "○",
  }
  return icons[status] or "○"
end

---Get highlight group for a status
---@param status string
---@return string
local function get_status_hl(status)
  local highlights = {
    running = "DiagnosticInfo",
    completed = "DiagnosticOk",
    stuck = "DiagnosticError",
    needs_input = "DiagnosticWarn",
    pending = "Comment",
  }
  return highlights[status] or "Comment"
end

---Format duration from start time to now
---@param started_at string ISO timestamp
---@return string
local function format_duration(started_at)
  -- Parse ISO timestamp (simplified)
  local pattern = "(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):(%d+)"
  local y, m, d, h, min, s = started_at:match(pattern)
  if not y then
    return "?"
  end

  local start_time = os.time({
    year = tonumber(y),
    month = tonumber(m),
    day = tonumber(d),
    hour = tonumber(h),
    min = tonumber(min),
    sec = tonumber(s),
  })

  local elapsed = os.time() - start_time
  if elapsed < 60 then
    return string.format("%ds", elapsed)
  elseif elapsed < 3600 then
    return string.format("%dm", math.floor(elapsed / 60))
  else
    return string.format("%dh%dm", math.floor(elapsed / 3600), math.floor((elapsed % 3600) / 60))
  end
end

---Analyze convergence trend from iteration history
---@param history table[] Array of {iter, outcome} objects
---@return string trend "converging"|"diverging"|"stuck"|"stable"|"unknown"
---@return string icon Trend indicator icon
local function analyze_trend(history)
  if not history or #history < 3 then
    return "unknown", ""
  end

  -- Get last 3 outcomes
  local last_three = {}
  for i = math.max(1, #history - 2), #history do
    table.insert(last_three, history[i].outcome or "")
  end

  -- Check if same error repeated (stuck)
  local unique = {}
  for _, v in ipairs(last_three) do
    unique[v] = true
  end
  local unique_count = 0
  for _ in pairs(unique) do
    unique_count = unique_count + 1
  end

  if unique_count == 1 and #last_three >= 3 then
    return "stuck", "↓"
  end

  -- Analyze error progression
  -- Heuristic: errors getting shorter/more specific = converging
  -- Heuristic: progression through stages (compile -> test -> lint) = converging
  local lengths = {}
  for _, h in ipairs(history) do
    table.insert(lengths, #(h.outcome or ""))
  end

  -- Check if lengths are trending down (more specific errors)
  local trend_down = 0
  local recent_start = math.max(1, #lengths - 4)
  for i = recent_start + 1, #lengths do
    if lengths[i] < lengths[i - 1] then
      trend_down = trend_down + 1
    end
  end

  local recent_count = #lengths - recent_start
  if recent_count > 0 and trend_down > recent_count / 2 then
    return "converging", "↑"
  end

  -- Check for stage progression keywords
  local stages = { "import", "syntax", "type", "compile", "build", "test", "lint", "pass" }
  local stage_progression = 0
  local last_stage = 0
  for _, h in ipairs(history) do
    local outcome = (h.outcome or ""):lower()
    for stage_idx, stage in ipairs(stages) do
      if outcome:find(stage) then
        if stage_idx > last_stage then
          stage_progression = stage_progression + 1
          last_stage = stage_idx
        end
        break
      end
    end
  end

  if stage_progression >= 2 then
    return "converging", "↑"
  end

  -- Check for diverging (scope expanding, more files)
  if #history > 5 then
    local early_len = 0
    local late_len = 0
    for i = 1, 3 do
      early_len = early_len + #(history[i].outcome or "")
    end
    for i = #history - 2, #history do
      late_len = late_len + #(history[i].outcome or "")
    end
    if late_len > early_len * 1.5 then
      return "diverging", "↓"
    end
  end

  return "stable", "→"
end

---Read all status files
---@param config ChiefWiggumConfig
---@return table[] List of status objects
local function read_all_statuses(config)
  local status_path = config.vault_path .. "/" .. config.status_dir
  local statuses = {}

  if not uv then
    return statuses
  end

  local handle = uv.fs_scandir(status_path)
  if not handle then
    return statuses
  end

  while true do
    local name, type = uv.fs_scandir_next(handle)
    if not name then
      break
    end

    if type == "file" and name:match("%.json$") then
      local file = io.open(status_path .. "/" .. name, "r")
      if file then
        local content = file:read("*a")
        file:close()
        local ok, data = pcall(vim.json.decode, content)
        if ok and data then
          table.insert(statuses, data)
        end
      end
    end
  end

  -- Sort: running first, then by last_update descending
  table.sort(statuses, function(a, b)
    if a.status == "running" and b.status ~= "running" then
      return true
    elseif a.status ~= "running" and b.status == "running" then
      return false
    end
    return (a.last_update or "") > (b.last_update or "")
  end)

  return statuses
end

---Build status window content
---@param config ChiefWiggumConfig
---@return string[] lines
---@return table[] highlights {line, col_start, col_end, hl_group}
local function build_content(config)
  local lines = {}
  local highlights = {}

  -- Header
  table.insert(lines, "╭─────────────────────────────────────────────────────────╮")
  table.insert(lines, "│            CHIEF WIGGUM COMMAND CENTER                  │")
  table.insert(lines, "│               \"Bake 'em away, toys.\"                    │")
  table.insert(lines, "╰─────────────────────────────────────────────────────────╯")
  table.insert(lines, "")

  local statuses = read_all_statuses(config)

  if #statuses == 0 then
    table.insert(lines, "  No active tasks.")
    table.insert(lines, "")
    table.insert(lines, "  Use :ChiefWiggumDispatch <file> to dispatch a task")
    table.insert(lines, "  or press " .. (config.keymaps.dispatch or "<leader>wd") .. " on a task file.")
  else
    -- Count by status
    local counts = { running = 0, completed = 0, stuck = 0, needs_input = 0 }
    for _, s in ipairs(statuses) do
      counts[s.status] = (counts[s.status] or 0) + 1
    end

    -- Summary line
    local summary = string.format(
      "  Agents: %d running  %d completed  %d stuck  %d waiting",
      counts.running,
      counts.completed,
      counts.stuck,
      counts.needs_input
    )
    table.insert(lines, summary)
    table.insert(lines, "")
    table.insert(lines, "  ─────────────────────────────────────────────────────")
    table.insert(lines, "")

    -- Each task
    for _, status in ipairs(statuses) do
      local icon = get_status_icon(status.status)
      local hl = get_status_hl(status.status)

      -- Task name line
      local name_line = string.format("  %s %s", icon, status.name or status.task)
      local line_num = #lines
      table.insert(lines, name_line)
      table.insert(highlights, { line_num, 2, 3, hl })

      -- Progress line with trend indicator
      local progress = ""
      if status.status == "running" then
        local duration = format_duration(status.started_at or status.last_update or "")
        local trend, trend_icon = analyze_trend(status.iterations_history)
        local trend_str = ""
        if trend_icon ~= "" then
          trend_str = " " .. trend_icon .. " " .. trend
        end
        progress = string.format(
          "    iter %d/%d • %s%s",
          status.iteration or 0,
          status.max_iterations or 20,
          duration,
          trend_str
        )
      elseif status.status == "completed" then
        progress = string.format("    completed in %d iterations", status.iteration or 0)
      elseif status.status == "stuck" then
        progress = string.format("    stuck at iter %d", status.iteration or 0)
      elseif status.status == "needs_input" then
        progress = "    waiting for input"
      end
      table.insert(lines, progress)

      -- Last outcome (if available)
      if status.iterations_history and #status.iterations_history > 0 then
        local last = status.iterations_history[#status.iterations_history]
        if last.outcome then
          local outcome = "    └─ " .. last.outcome:sub(1, 50)
          if #last.outcome > 50 then
            outcome = outcome .. "..."
          end
          table.insert(lines, outcome)
        end
      end

      table.insert(lines, "")
    end
  end

  -- Footer
  table.insert(lines, "  ─────────────────────────────────────────────────────")
  table.insert(lines, "  [q] close  [r] refresh  [d] dispatch  [c] command.md")

  return lines, highlights
end

---Refresh status window content
function M.refresh()
  if not M.is_open() then
    return
  end

  local config = require("chief-wiggum.config").get()
  local lines, highlights = build_content(config)

  vim.api.nvim_buf_set_option(status_buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(status_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(status_buf, "modifiable", false)

  -- Apply highlights
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(status_buf, -1, hl[4], hl[1], hl[2], hl[3])
  end
end

---Show status window
---@param config ChiefWiggumConfig
function M.show(config)
  -- If already open, close it (toggle behavior)
  if M.is_open() then
    M.close()
    return
  end

  -- Create buffer
  status_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(status_buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(status_buf, "filetype", "chief-wiggum-status")

  -- Calculate window size
  local width = 60
  local height = 25
  local ui = vim.api.nvim_list_uis()[1]
  local row = math.floor((ui.height - height) / 2)
  local col = math.floor((ui.width - width) / 2)

  -- Create window
  status_win = vim.api.nvim_open_win(status_buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " Chief Wiggum ",
    title_pos = "center",
  })

  -- Set window options
  vim.api.nvim_win_set_option(status_win, "winblend", 10)
  vim.api.nvim_win_set_option(status_win, "cursorline", true)

  -- Populate content
  M.refresh()

  -- Set up keymaps for the status window
  local opts = { buffer = status_buf, noremap = true, silent = true }
  vim.keymap.set("n", "q", M.close, opts)
  vim.keymap.set("n", "<Esc>", M.close, opts)
  vim.keymap.set("n", "r", M.refresh, opts)
  vim.keymap.set("n", "d", function()
    M.close()
    vim.cmd("ChiefWiggumDispatch")
  end, opts)
  vim.keymap.set("n", "c", function()
    M.close()
    vim.cmd("edit " .. config.vault_path .. "/COMMAND.md")
  end, opts)

  -- Auto-refresh every 2 seconds while open
  if not uv then return end
  local timer = uv.new_timer()
  timer:start(
    2000,
    2000,
    vim.schedule_wrap(function()
      if M.is_open() then
        M.refresh()
      else
        timer:stop()
        timer:close()
      end
    end)
  )
end

return M
