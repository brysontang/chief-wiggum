---Stage parsing, navigation, and dispatch
---Enables pipeline-based task workflows

local M = {}

---@class Stage
---@field name string Stage name (e.g., "IMPLEMENT")
---@field line number Line number in buffer (1-indexed)
---@field status "active"|"done"|"pending" Stage status
---@field agent string|nil Agent to use for this stage
---@field verification string|nil Verification command
---@field items table[] Checklist items {line, done, text}

---Parse stages from current buffer or specified lines
---@param bufnr number|nil Buffer number (nil for current)
---@return Stage[] stages Array of parsed stages
function M.parse_stages(bufnr)
  bufnr = bufnr or 0
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local stages = {}
  local current_stage = nil
  local in_verification = false
  local verification_lines = {}

  for i, line in ipairs(lines) do
    -- Stage header: ### STAGENAME or ### STAGENAME ← ACTIVE or ### STAGENAME ✓
    if line:match("^### ") then
      -- Save previous stage
      if current_stage then
        if #verification_lines > 0 then
          current_stage.verification = table.concat(verification_lines, "\n")
        end
        table.insert(stages, current_stage)
      end

      local name = line:match("^### (%u+)")
      local status = "pending"

      if line:match("←") or line:match("ACTIVE") then
        status = "active"
      elseif line:match("✓") or line:match("DONE") then
        status = "done"
      end

      current_stage = {
        name = name,
        line = i,
        status = status,
        agent = nil,
        verification = nil,
        items = {},
      }
      in_verification = false
      verification_lines = {}

    elseif current_stage then
      -- Agent line: Agent: agentname
      local agent = line:match("^Agent:%s*(%w+)")
      if agent then
        current_stage.agent = agent
      end

      -- Checklist item: - [ ] or - [x]
      if line:match("^%- %[.%]") then
        local done = line:match("^%- %[x%]") ~= nil
        local text = line:match("^%- %[.%]%s*(.*)") or ""
        table.insert(current_stage.items, {
          line = i,
          done = done,
          text = text,
        })
      end

      -- Verification block
      if line:match("^Verification:") then
        in_verification = true
        -- Check for inline verification: Verification: `cmd`
        local inline = line:match("^Verification:%s*`(.+)`")
        if inline then
          current_stage.verification = inline
          in_verification = false
        end
      elseif in_verification then
        if line:match("^```") then
          if #verification_lines > 0 then
            -- End of code block
            in_verification = false
          end
          -- Start of code block, skip the ``` line
        elseif line:match("^###") or line:match("^## ") then
          -- Next section, stop
          in_verification = false
        elseif not line:match("^%s*$") or #verification_lines > 0 then
          -- Non-empty line or we've started collecting
          table.insert(verification_lines, line)
        end
      end
    end
  end

  -- Don't forget last stage
  if current_stage then
    if #verification_lines > 0 then
      current_stage.verification = table.concat(verification_lines, "\n")
    end
    table.insert(stages, current_stage)
  end

  return stages
end

---Get the current (active) stage
---@param bufnr number|nil
---@return Stage|nil stage
function M.current_stage(bufnr)
  local stages = M.parse_stages(bufnr)

  -- First, look for explicitly active stage
  for _, stage in ipairs(stages) do
    if stage.status == "active" then
      return stage
    end
  end

  -- If none active, find first non-done stage
  for _, stage in ipairs(stages) do
    if stage.status ~= "done" then
      return stage
    end
  end

  -- All done? Return last stage
  return stages[#stages]
end

---Get the next stage after current
---@param bufnr number|nil
---@return Stage|nil stage
function M.next_stage(bufnr)
  local stages = M.parse_stages(bufnr)
  local found_current = false

  for _, stage in ipairs(stages) do
    if found_current then
      return stage
    end
    if stage.status == "active" then
      found_current = true
    end
  end

  return nil
end

---Mark current stage as done and advance to next
---@param bufnr number|nil
function M.advance(bufnr)
  bufnr = bufnr or 0
  local stages = M.parse_stages(bufnr)

  for i, stage in ipairs(stages) do
    if stage.status == "active" then
      -- Mark current as done
      local line = vim.api.nvim_buf_get_lines(bufnr, stage.line - 1, stage.line, false)[1]
      -- Remove active marker and add done marker
      line = line:gsub("%s*←%s*ACTIVE", "")
      line = line:gsub("%s*←.*$", "")
      if not line:match("✓") then
        line = line .. " ✓"
      end
      vim.api.nvim_buf_set_lines(bufnr, stage.line - 1, stage.line, false, { line })

      -- Mark next as active
      if stages[i + 1] then
        local next_line = vim.api.nvim_buf_get_lines(bufnr, stages[i + 1].line - 1, stages[i + 1].line, false)[1]
        -- Remove any existing markers
        next_line = next_line:gsub("%s*←%s*ACTIVE", "")
        next_line = next_line:gsub("%s*✓", "")
        next_line = next_line .. " ← ACTIVE"
        vim.api.nvim_buf_set_lines(bufnr, stages[i + 1].line - 1, stages[i + 1].line, false, { next_line })

        vim.notify(
          string.format("[chief-wiggum] Advanced to %s stage", stages[i + 1].name),
          vim.log.levels.INFO
        )
      else
        vim.notify("[chief-wiggum] All stages complete!", vim.log.levels.INFO)
      end

      return
    end
  end

  -- No active stage found, activate first pending
  for _, stage in ipairs(stages) do
    if stage.status == "pending" then
      local line = vim.api.nvim_buf_get_lines(bufnr, stage.line - 1, stage.line, false)[1]
      line = line .. " ← ACTIVE"
      vim.api.nvim_buf_set_lines(bufnr, stage.line - 1, stage.line, false, { line })
      vim.notify(string.format("[chief-wiggum] Started %s stage", stage.name), vim.log.levels.INFO)
      return
    end
  end
end

---Go back to previous stage (mark current as pending)
---@param bufnr number|nil
function M.regress(bufnr)
  bufnr = bufnr or 0
  local stages = M.parse_stages(bufnr)

  for i, stage in ipairs(stages) do
    if stage.status == "active" and i > 1 then
      -- Mark current as pending
      local line = vim.api.nvim_buf_get_lines(bufnr, stage.line - 1, stage.line, false)[1]
      line = line:gsub("%s*←%s*ACTIVE", "")
      vim.api.nvim_buf_set_lines(bufnr, stage.line - 1, stage.line, false, { line })

      -- Mark previous as active (remove done marker)
      local prev_line = vim.api.nvim_buf_get_lines(bufnr, stages[i - 1].line - 1, stages[i - 1].line, false)[1]
      prev_line = prev_line:gsub("%s*✓", "")
      prev_line = prev_line .. " ← ACTIVE"
      vim.api.nvim_buf_set_lines(bufnr, stages[i - 1].line - 1, stages[i - 1].line, false, { prev_line })

      vim.notify(
        string.format("[chief-wiggum] Regressed to %s stage", stages[i - 1].name),
        vim.log.levels.INFO
      )
      return
    end
  end
end

---Get agent name for current stage
---@param bufnr number|nil
---@return string|nil agent
function M.current_agent(bufnr)
  local stage = M.current_stage(bufnr)
  if not stage then
    return nil
  end

  -- Use explicit agent if set
  if stage.agent then
    return stage.agent
  end

  -- Fall back to config mapping
  local config = require("chief-wiggum.config").get()
  if config.agent_for_stage and config.agent_for_stage[stage.name] then
    return config.agent_for_stage[stage.name]
  end

  return config.default_agent or "implement"
end

---Get verification command for current stage
---@param bufnr number|nil
---@return string|nil verification
function M.current_verification(bufnr)
  local stage = M.current_stage(bufnr)
  if stage then
    return stage.verification
  end
  return nil
end

---Check if all items in current stage are done
---@param bufnr number|nil
---@return boolean all_done
function M.stage_items_complete(bufnr)
  local stage = M.current_stage(bufnr)
  if not stage or #stage.items == 0 then
    return true
  end

  for _, item in ipairs(stage.items) do
    if not item.done then
      return false
    end
  end

  return true
end

---Toggle checklist item under cursor
---@param bufnr number|nil
function M.toggle_item(bufnr)
  bufnr = bufnr or 0
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_nr = cursor[1]
  local line = vim.api.nvim_buf_get_lines(bufnr, line_nr - 1, line_nr, false)[1]

  if line:match("^%- %[ %]") then
    line = line:gsub("^%- %[ %]", "- [x]")
  elseif line:match("^%- %[x%]") then
    line = line:gsub("^%- %[x%]", "- [ ]")
  else
    return -- Not a checklist item
  end

  vim.api.nvim_buf_set_lines(bufnr, line_nr - 1, line_nr, false, { line })
end

---Dispatch current stage to appropriate agent
---@param bufnr number|nil
function M.dispatch_current(bufnr)
  bufnr = bufnr or 0
  local stage = M.current_stage(bufnr)

  if not stage then
    vim.notify("[chief-wiggum] No stage found", vim.log.levels.ERROR)
    return
  end

  local agent = M.current_agent(bufnr)

  if agent == "human" then
    vim.notify(
      string.format("[chief-wiggum] %s stage requires human action", stage.name),
      vim.log.levels.INFO
    )
    return
  end

  -- Get task file path
  local task_file = vim.api.nvim_buf_get_name(bufnr)
  if task_file == "" then
    vim.notify("[chief-wiggum] Buffer has no file", vim.log.levels.ERROR)
    return
  end

  -- Dispatch via dispatch module
  local config = require("chief-wiggum.config").get()
  require("chief-wiggum.dispatch").dispatch_stage(task_file, stage.name, agent, config)
end

---Jump to stage by name
---@param stage_name string
---@param bufnr number|nil
function M.jump_to_stage(stage_name, bufnr)
  bufnr = bufnr or 0
  local stages = M.parse_stages(bufnr)

  for _, stage in ipairs(stages) do
    if stage.name == stage_name or stage.name:lower() == stage_name:lower() then
      vim.api.nvim_win_set_cursor(0, { stage.line, 0 })
      return
    end
  end

  vim.notify("[chief-wiggum] Stage not found: " .. stage_name, vim.log.levels.WARN)
end

---Fold expression for stage-based folding
---@param lnum number Line number
---@return string fold_level
function M.fold_expr(lnum)
  local line = vim.fn.getline(lnum)

  -- Stage headers start a fold
  if line:match("^### ") then
    return ">1"
  end

  -- Section headers (##) start level 0
  if line:match("^## ") then
    return ">0"
  end

  -- Everything else continues current fold
  return "="
end

---Get summary of all stages for status display
---@param bufnr number|nil
---@return table summary {total, done, active_name, next_agent}
function M.get_summary(bufnr)
  local stages = M.parse_stages(bufnr)
  local done = 0
  local active_name = nil
  local next_agent = nil

  for _, stage in ipairs(stages) do
    if stage.status == "done" then
      done = done + 1
    elseif stage.status == "active" then
      active_name = stage.name
      next_agent = stage.agent
    end
  end

  return {
    total = #stages,
    done = done,
    active_name = active_name,
    next_agent = next_agent,
  }
end

return M
