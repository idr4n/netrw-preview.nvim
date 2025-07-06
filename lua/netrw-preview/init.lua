---@class NetrwPreview
local M = {}

local config = require("netrw-preview.config")
local Preview = require("netrw-preview.preview")

---@type NetrwPreview.Preview?
local current_preview = nil

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
        local reveal = require("netrw-preview.reveal")
        local cur_buf = vim.fn.bufnr("#")

        -- Check if alternate buffer exists and is valid
        if cur_buf ~= -1 and vim.api.nvim_buf_is_valid(cur_buf) and vim.bo[cur_buf].buflisted then
          reveal.current_bufnr = cur_buf
        end
      end
    end,
    desc = "Track buffer context",
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
          M.enable_preview()
        end)
      end
    end,
    desc = "Setup netrw preview mappings",
  })
end

---Get or create the current preview instance
---@return NetrwPreview.Preview
local function get_preview_instance()
  if not current_preview then
    current_preview = Preview.create({ config = config.options })
  end
  return current_preview
end

---Enable preview functionality
function M.enable_preview()
  local preview = get_preview_instance()
  preview:enable_preview()
end

---Disable preview functionality
---@param opts? {delete_buffer?: boolean} Options for disabling preview
function M.disable_preview(opts)
  if current_preview then
    current_preview:disable_preview(opts)
    if opts and opts.delete_buffer then
      current_preview = nil
    end
  end
end

---Toggle preview functionality on/off
function M.toggle_preview()
  local preview = get_preview_instance()
  preview:toggle_preview()
end

---Check if preview is currently enabled
---@return boolean True if preview is enabled
function M.is_preview_enabled()
  if not current_preview then
    return false
  end
  return current_preview:is_preview_enabled()
end

---Get the preview buffer handle
---@return integer? Buffer handle or nil if not created
function M.get_preview_buffer()
  if not current_preview then
    return nil
  end
  return current_preview:get_preview_buffer()
end

---Reveal current file in netrw
function M.reveal()
  require("netrw-preview.reveal").reveal()
end

---Reveal current file in Lexplore
function M.reveal_lex()
  require("netrw-preview.reveal").reveal(true)
end

---Reveal specified file in netrw
---@param file_path string Path to the file to reveal
function M.reveal_file(file_path)
  require("netrw-preview.reveal").reveal_file(file_path)
end

---Reveal specified file in Lexplore
---@param file_path string Path to the file to reveal
function M.reveal_file_lex(file_path)
  require("netrw-preview.reveal").reveal_file(file_path, true)
end

---Toggle NetrwReveal (open netrw or close if already open)
function M.reveal_file_toggle()
  require("netrw-preview.reveal").toggle()
end

---Toggle NetrwRevealLex (open Lexplore or close if already open)
function M.reveal_file_lex_toggle()
  require("netrw-preview.reveal").toggle(true)
end

return M
