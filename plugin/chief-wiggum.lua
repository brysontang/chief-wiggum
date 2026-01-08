-- Chief Wiggum Neovim Plugin Auto-loader
-- This file is automatically loaded by Neovim's plugin system

-- Prevent double-loading
if vim.g.loaded_chief_wiggum then
  return
end
vim.g.loaded_chief_wiggum = true

-- Require Neovim 0.9+ for vim.uv
if vim.fn.has("nvim-0.9") == 0 then
  vim.notify("[chief-wiggum] Requires Neovim 0.9 or later", vim.log.levels.ERROR)
  return
end

-- Auto-setup with defaults if not manually configured
-- Users can call require("chief-wiggum").setup(opts) to override
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    -- Only auto-setup if not already configured
    if not vim.g.chief_wiggum_configured then
      -- Delay to allow lazy.nvim or other plugin managers to configure first
      vim.defer_fn(function()
        if not vim.g.chief_wiggum_configured then
          require("chief-wiggum").setup()
        end
      end, 100)
    end
  end,
  once = true,
})
