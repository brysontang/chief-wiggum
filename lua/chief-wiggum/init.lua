---Chief Wiggum - Vim-native command center for orchestrating autonomous Claude Code agents
---
---"Bake 'em away, toys."
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

  vim.notify("[chief-wiggum] Vault initialized at " .. vault, vim.log.levels.INFO)
end

---Show status window
function M.show_status()
  local config = require("chief-wiggum.config").get()
  require("chief-wiggum.status").show(config)
end

---Dispatch a task
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
      file:write("## Verification Command\n```bash\n\n```\n\n")
      file:write("## Prompt\n````\n\n````\n")
      file:close()
    end
  end

  vim.cmd("edit " .. task_path)
  vim.notify("[chief-wiggum] Created new task: " .. filename, vim.log.levels.INFO)
end

---Setup chief-wiggum with user configuration
---@param opts? table User configuration overrides
function M.setup(opts)
  -- Setup configuration
  require("chief-wiggum.config").setup(opts)
  local config = require("chief-wiggum.config").get()

  -- Ensure vault exists
  if vim.fn.isdirectory(config.vault_path) == 0 then
    M.init_vault()
  end

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
    desc = "Dispatch a task to Claude Code",
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

  -- Setup keymaps
  local keymaps = config.keymaps
  if keymaps then
    local map_opts = { noremap = true, silent = true }

    if keymaps.status then
      vim.keymap.set("n", keymaps.status, M.show_status, vim.tbl_extend("force", map_opts, {
        desc = "Chief Wiggum: Status window",
      }))
    end

    if keymaps.dispatch then
      vim.keymap.set("n", keymaps.dispatch, function()
        require("chief-wiggum.dispatch").dispatch_current()
      end, vim.tbl_extend("force", map_opts, {
        desc = "Chief Wiggum: Dispatch current task",
      }))
    end

    if keymaps.command then
      vim.keymap.set("n", keymaps.command, M.open_command, vim.tbl_extend("force", map_opts, {
        desc = "Chief Wiggum: Open COMMAND.md",
      }))
    end

    if keymaps.recon then
      vim.keymap.set("n", keymaps.recon, M.run_recon, vim.tbl_extend("force", map_opts, {
        desc = "Chief Wiggum: Run recon scan",
      }))
    end

    if keymaps.queue then
      vim.keymap.set("n", keymaps.queue, M.open_queue, vim.tbl_extend("force", map_opts, {
        desc = "Chief Wiggum: Open QUEUE.md",
      }))
    end
  end

  -- Setup file watcher if enabled
  if config.auto_reload then
    require("chief-wiggum.watcher").setup(config)
  end
end

return M
