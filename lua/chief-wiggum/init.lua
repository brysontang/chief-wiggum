---Chief Wiggum - Vim-native command center for orchestrating autonomous AI agents
---
---"Bake 'em away, toys."
---
---State lives in files, not context. Each dispatch is a fresh start.
---
---@module chief-wiggum

local M = {}

---@type ChiefWiggumConfig
M.config = nil

---Initialize vault directory structure
function M.init_vault()
  local config = require("chief-wiggum.config").get()
  local vault = config.vault_path

  -- Create directory structure
  local dirs = {
    "",
    "/tasks",
    "/tasks/features",
    "/status",
    "/logs",
    "/prompts",
    "/templates",
    "/decisions",
    "/agents",
  }

  for _, dir in ipairs(dirs) do
    vim.fn.mkdir(vault .. dir, "p")
  end

  -- Copy templates from plugin directory
  local source = debug.getinfo(1, "S").source:sub(2)
  local plugin_root = vim.fn.fnamemodify(source, ":h:h:h")
  local templates_src = plugin_root .. "/templates/"

  local templates = {
    { "COMMAND.md", "/COMMAND.md" },
    { "QUEUE.md", "/QUEUE.md" },
    { "feature.md", "/templates/feature.md" },
    { "decision.md", "/templates/decision.md" },
  }

  for _, tmpl in ipairs(templates) do
    local src = templates_src .. tmpl[1]
    local dst = vault .. tmpl[2]
    if vim.fn.filereadable(src) == 1 and vim.fn.filereadable(dst) == 0 then
      vim.fn.system({ "cp", src, dst })
    end
  end

  -- Create worktree base directory in project root (if in a git repo)
  local git_root = vim.fn.trim(vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"))
  if vim.v.shell_error == 0 and git_root ~= "" then
    local worktree_base = git_root .. "/" .. config.worktree_base
    vim.fn.mkdir(worktree_base, "p")
    vim.notify("[chief-wiggum] Worktree base created at " .. worktree_base, vim.log.levels.INFO)
  end

  vim.notify("[chief-wiggum] Vault initialized at " .. vault, vim.log.levels.INFO)
end

---Show status window
function M.show_status()
  local config = require("chief-wiggum.config").get()
  require("chief-wiggum.status").show(config)
end

---Dispatch current stage
function M.dispatch_current()
  require("chief-wiggum.dispatch").dispatch_current()
end

---Dispatch a specific file
---@param file_path string|nil Path to task file
function M.dispatch(file_path)
  local config = require("chief-wiggum.config").get()
  require("chief-wiggum.dispatch").dispatch(file_path, config)
end

---Run recon scan
---@param scope string|nil Directory to scan
function M.run_recon(scope)
  local config = require("chief-wiggum.config").get()
  require("chief-wiggum.dispatch").recon(config, scope)
end

---Open COMMAND.md
function M.open_command()
  local config = require("chief-wiggum.config").get()
  vim.cmd("edit " .. config.vault_path .. "/COMMAND.md")
end

---Open QUEUE.md
function M.open_queue()
  local config = require("chief-wiggum.config").get()
  vim.cmd("edit " .. config.vault_path .. "/QUEUE.md")
end

---Advance to next stage
function M.advance_stage()
  require("chief-wiggum.stages").advance()
end

---Regress to previous stage
function M.regress_stage()
  require("chief-wiggum.stages").regress()
end

---Toggle checklist item under cursor
function M.toggle_item()
  require("chief-wiggum.stages").toggle_item()
end

---Open worktree in file explorer
function M.open_worktree()
  local config = require("chief-wiggum.config").get()
  local stages = require("chief-wiggum.stages")

  -- Get task ID from current file
  local file = vim.fn.expand("%:p")
  local task_id = vim.fn.fnamemodify(file, ":t:r")

  if task_id and task_id ~= "" then
    require("chief-wiggum.worktree").open(task_id, config.file_explorer)
  else
    vim.notify("[chief-wiggum] Cannot determine task ID from current file", vim.log.levels.WARN)
  end
end

---Create a new task from template
---@param name string Task name
function M.new_task(name)
  local config = require("chief-wiggum.config").get()

  -- Sanitize name for filename
  local filename = name:lower():gsub("[^%w%-_]", "-"):gsub("%-+", "-")
  local task_path = config.vault_path .. "/tasks/features/" .. filename .. ".md"

  -- Check if exists
  if vim.fn.filereadable(task_path) == 1 then
    vim.notify("[chief-wiggum] Task already exists: " .. task_path, vim.log.levels.WARN)
    vim.cmd("edit " .. task_path)
    return
  end

  -- Copy template
  local template_path = config.vault_path .. "/templates/feature.md"
  if vim.fn.filereadable(template_path) == 0 then
    -- Use built-in template
    local source = debug.getinfo(1, "S").source:sub(2)
    local plugin_root = vim.fn.fnamemodify(source, ":h:h:h")
    template_path = plugin_root .. "/templates/feature.md"
  end

  if vim.fn.filereadable(template_path) == 1 then
    vim.fn.system({ "cp", template_path, task_path })
    -- Replace placeholder in file
    vim.fn.system({
      "sed",
      "-i",
      "",
      "s/{{TASK_NAME}}/" .. name .. "/g",
      task_path,
    })
  else
    -- Create minimal template
    local file = io.open(task_path, "w")
    if file then
      file:write("# " .. name .. "\n\n")
      file:write("## Objective\n\n")
      file:write("## Stages\n\n")
      file:write("### IMPLEMENT ← ACTIVE\n")
      file:write("Agent: implement\n")
      file:write("Verification: `echo DONE`\n\n")
      file:write("## Log\n")
      file:close()
    end
  end

  vim.cmd("edit " .. task_path)
  vim.notify("[chief-wiggum] Created new task: " .. filename, vim.log.levels.INFO)
end

---List worktrees with staleness and dirty status
function M.list_worktrees()
  local wt_module = require("chief-wiggum.worktree")
  local config = require("chief-wiggum.config").get()
  local worktrees = wt_module.list()

  if #worktrees == 0 then
    vim.notify("[chief-wiggum] No worktrees found", vim.log.levels.INFO)
    return
  end

  local lines = { "Worktrees:" }
  local git_root = vim.fn.trim(vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"))
  local worktree_base = config.worktree_base
  if not worktree_base:match("^/") then
    worktree_base = git_root .. "/" .. worktree_base
  end

  for _, wt in ipairs(worktrees) do
    -- Skip the main worktree
    if wt.bare then
      goto continue
    end

    -- Extract task_id from path
    local task_id = wt.path:match("/([^/]+)$")
    local branch = wt.branch or "detached"
    local status_parts = {}

    -- Check if this is a chief-wiggum managed worktree (plain string match, not pattern)
    if task_id and wt.path:find(config.worktree_base, 1, true) then
      -- Check dirty status
      local is_dirty = wt_module.is_dirty(task_id)
      if is_dirty then
        table.insert(status_parts, "dirty")
      end

      -- Check staleness (behind/ahead of main)
      local behind, ahead = wt_module.staleness(task_id)
      if behind > 0 or ahead > 0 then
        local staleness = {}
        if behind > 0 then
          table.insert(staleness, string.format("-%d", behind))
        end
        if ahead > 0 then
          table.insert(staleness, string.format("+%d", ahead))
        end
        table.insert(status_parts, table.concat(staleness, "/"))
      end
    end

    -- Build the line
    local status_str = #status_parts > 0 and " [" .. table.concat(status_parts, ", ") .. "]" or ""
    local line = string.format("  %s (%s)%s", wt.path, branch, status_str)
    table.insert(lines, line)

    ::continue::
  end

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

---Prune orphaned worktrees
function M.prune_worktrees()
  require("chief-wiggum.worktree").prune_orphaned()
end

---Setup keymaps for task files
---@param config ChiefWiggumConfig
local function setup_task_autocmd(config)
  vim.api.nvim_create_autocmd("BufEnter", {
    pattern = { "*/tasks/features/*.md", "*/.chief-wiggum/tasks/*.md" },
    callback = function(ev)
      local opts = { buffer = ev.buf, noremap = true, silent = true }

      -- Stage navigation
      vim.keymap.set("n", "gn", M.advance_stage,
        vim.tbl_extend("force", opts, { desc = "Advance to next stage" }))
      vim.keymap.set("n", "gp", M.regress_stage,
        vim.tbl_extend("force", opts, { desc = "Regress to previous stage" }))
      vim.keymap.set("n", "<CR>", M.dispatch_current,
        vim.tbl_extend("force", opts, { desc = "Dispatch current stage" }))
      vim.keymap.set("n", "<Space>", M.toggle_item,
        vim.tbl_extend("force", opts, { desc = "Toggle checklist item" }))

      -- Folding by stage
      vim.opt_local.foldmethod = "expr"
      vim.opt_local.foldexpr = "v:lua.require('chief-wiggum.stages').fold_expr(v:lnum)"
      vim.opt_local.foldlevel = 1
    end,
    group = vim.api.nvim_create_augroup("ChiefWiggumTask", { clear = true }),
  })
end

---Setup chief-wiggum with user configuration
---@param opts? table User configuration overrides
function M.setup(opts)
  -- Mark as configured
  vim.g.chief_wiggum_configured = true

  -- Setup configuration
  require("chief-wiggum.config").setup(opts)
  local config = require("chief-wiggum.config").get()

  -- NOTE: Vault is NOT auto-created. User must run :ChiefWiggumInit explicitly.
  -- This prevents .wiggum directories appearing in random places.

  -- Create user commands
  vim.api.nvim_create_user_command("ChiefWiggumStatus", M.show_status, {
    desc = "Show Chief Wiggum status window",
  })

  vim.api.nvim_create_user_command("ChiefWiggumDispatch", function(cmd_opts)
    local file = cmd_opts.args ~= "" and cmd_opts.args or nil
    M.dispatch(file)
  end, {
    nargs = "?",
    complete = "file",
    desc = "Dispatch a task to an agent",
  })

  vim.api.nvim_create_user_command("ChiefWiggumRecon", function(cmd_opts)
    local scope = cmd_opts.args ~= "" and cmd_opts.args or nil
    M.run_recon(scope)
  end, {
    nargs = "?",
    complete = "dir",
    desc = "Run recon scan on codebase",
  })

  vim.api.nvim_create_user_command("ChiefWiggumInit", M.init_vault, {
    desc = "Initialize Chief Wiggum vault",
  })

  vim.api.nvim_create_user_command("ChiefWiggumNew", function(cmd_opts)
    if cmd_opts.args == "" then
      vim.ui.input({ prompt = "Task name: " }, function(input)
        if input and input ~= "" then
          M.new_task(input)
        end
      end)
    else
      M.new_task(cmd_opts.args)
    end
  end, {
    nargs = "?",
    desc = "Create a new task from template",
  })

  vim.api.nvim_create_user_command("ChiefWiggumAdvance", M.advance_stage, {
    desc = "Advance to next stage",
  })

  vim.api.nvim_create_user_command("ChiefWiggumRegress", M.regress_stage, {
    desc = "Regress to previous stage",
  })

  vim.api.nvim_create_user_command("ChiefWiggumWorktrees", M.list_worktrees, {
    desc = "List all worktrees",
  })

  vim.api.nvim_create_user_command("ChiefWiggumPrune", M.prune_worktrees, {
    desc = "Prune orphaned worktrees",
  })

  -- Setup keymaps
  local keymaps = config.keymaps
  if keymaps then
    local map_opts = { noremap = true, silent = true }

    if keymaps.status then
      vim.keymap.set("n", keymaps.status, M.show_status,
        vim.tbl_extend("force", map_opts, { desc = "Chief Wiggum: Status window" }))
    end

    if keymaps.dispatch then
      vim.keymap.set("n", keymaps.dispatch, M.dispatch_current,
        vim.tbl_extend("force", map_opts, { desc = "Chief Wiggum: Dispatch current stage" }))
    end

    if keymaps.command then
      vim.keymap.set("n", keymaps.command, M.open_command,
        vim.tbl_extend("force", map_opts, { desc = "Chief Wiggum: Open COMMAND.md" }))
    end

    if keymaps.recon then
      vim.keymap.set("n", keymaps.recon, M.run_recon,
        vim.tbl_extend("force", map_opts, { desc = "Chief Wiggum: Run recon scan" }))
    end

    if keymaps.queue then
      vim.keymap.set("n", keymaps.queue, M.open_queue,
        vim.tbl_extend("force", map_opts, { desc = "Chief Wiggum: Open QUEUE.md" }))
    end

    if keymaps.advance then
      vim.keymap.set("n", keymaps.advance, M.advance_stage,
        vim.tbl_extend("force", map_opts, { desc = "Chief Wiggum: Advance stage" }))
    end

    if keymaps.regress then
      vim.keymap.set("n", keymaps.regress, M.regress_stage,
        vim.tbl_extend("force", map_opts, { desc = "Chief Wiggum: Regress stage" }))
    end

    if keymaps.toggle then
      vim.keymap.set("n", keymaps.toggle, M.toggle_item,
        vim.tbl_extend("force", map_opts, { desc = "Chief Wiggum: Toggle item" }))
    end

    if keymaps.worktree then
      vim.keymap.set("n", keymaps.worktree, M.open_worktree,
        vim.tbl_extend("force", map_opts, { desc = "Chief Wiggum: Open worktree" }))
    end
  end

  -- Setup task file autocommands
  setup_task_autocmd(config)

  -- Setup file watcher if enabled
  if config.auto_reload then
    require("chief-wiggum.watcher").setup(config)
  end
end

return M
