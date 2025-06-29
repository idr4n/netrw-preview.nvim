---@class NetrwPreview
local M = {}

local config = require("netrw-preview.config")

---Setup the netrw-preview plugin
---@param opts? NetrwPreview.Config User configuration options
function M.setup(opts)
  -- Setup configuration
  config.setup(opts)

  -- Create autocommand group
  local augroup = vim.api.nvim_create_augroup("NetrwPreview", { clear = true })

  -- Global autocmd for tracking buffer context
  vim.api.nvim_create_autocmd("BufEnter", {
    group = augroup,
    pattern = "*",
    callback = function()
      if vim.bo.filetype == "netrw" then
        -- Track buffer context
        local utils = require("netrw-preview.utils")
        local cur_buf = vim.fn.bufnr("#")

        -- Check if alternate buffer exists and is valid
        if cur_buf ~= -1 and vim.api.nvim_buf_is_valid(cur_buf) and vim.bo[cur_buf].buflisted then
          utils.current_bufnr = cur_buf
        end
      end
    end,
    desc = "Fix netrw chgwin issue and track buffer context",
  })

  -- Setup netrw mappings
  vim.api.nvim_create_autocmd("FileType", {
    group = augroup,
    pattern = "netrw",
    callback = function()
      require("netrw-preview.mappings").setup_buffer_mappings()

      -- Enable preview by default if configured
      if config.options.preview_enabled then
        vim.schedule(function()
          require("netrw-preview.preview").enable_preview()
        end)
      end
    end,
    desc = "Setup netrw preview mappings",
  })

  -- Auto-open netrw on startup if no file is specified
  if config.options.auto_open_netrw then
    vim.api.nvim_create_autocmd("VimEnter", {
      group = augroup,
      callback = function()
        if vim.fn.argc() == 0 and vim.fn.line2byte(vim.fn.line("$")) == -1 then
          vim.cmd("silent! Explore")
        end
      end,
      desc = "Auto-open netrw when starting with no files",
    })
  end
end

---Enable preview functionality
function M.enable_preview()
  require("netrw-preview.preview").enable_preview()
end

---Disable preview functionality
---@param opts? {delete_buffer?: boolean} Options for disabling preview
function M.disable_preview(opts)
  require("netrw-preview.preview").disable_preview(opts)
end

---Toggle preview functionality on/off
function M.toggle_preview()
  require("netrw-preview.preview").toggle_preview()
end

---Reveal current file in netrw
function M.reveal()
  require("netrw-preview.utils").NetrwReveal()
end

---Reveal current file in Lexplore
function M.reveal_lex()
  require("netrw-preview.utils").NetrwReveal(true)
end

---Reveal specified file in netrw
---@param file_path string Path to the file to reveal
function M.reveal_file(file_path)
  require("netrw-preview.utils").RevealInNetrw(file_path)
end

---Reveal specified file in Lexplore
---@param file_path string Path to the file to reveal
function M.reveal_file_lex(file_path)
  require("netrw-preview.utils").RevealInNetrw(file_path, true)
end

---Toggle NetrwReveal (open netrw or close if already open)
function M.reveal_file_toggle()
  require("netrw-preview.utils").toggle_reveal()
end

---Toggle NetrwRevealLex (open Lexplore or close if already open)
function M.reveal_file_lex_toggle()
  require("netrw-preview.utils").toggle_reveal(true)
end

return M
