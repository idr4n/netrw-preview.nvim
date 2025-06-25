---@class NetrwPreview.Utils
local M = {}

-- These will be set from current buffer when netrw is opened
---@type integer?
M.current_bufnr = nil
---@type integer?
M.alt_buffer = nil

---Reveal current file in netrw file explorer
---Opens netrw in the directory of the current file and highlights it
function M.NetrwReveal()
  local alt_bufnr = vim.fn.bufnr("#")

  -- Check if alternate buffer exists and is valid
  if alt_bufnr ~= -1 and vim.api.nvim_buf_is_valid(alt_bufnr) and vim.bo[alt_bufnr].buflisted then
    M.alt_buffer = alt_bufnr
  else
    M.alt_buffer = nil
  end

  if vim.bo.filetype == "netrw" then
    return
  end

  local current_file = vim.fn.expand("%:p")
  if current_file == "" then
    vim.cmd("silent Explore")
    return
  end

  M.current_bufnr = vim.fn.bufnr()

  local filename = vim.fn.expand("%:t")
  local filepath = vim.fn.expand("%:p:h")

  -- Use silent commands to prevent history pollution
  vim.fn.setreg("/", filename)
  vim.cmd("silent Explore " .. filepath)

  local ok = pcall(function()
    vim.cmd("silent normal! n")
  end)

  if not ok then
    vim.cmd("silent nohlsearch")
    return
  end

  vim.cmd("silent nohlsearch")
  vim.cmd.normal("zz")
end

---Reveal a specific file in netrw
---@param file_path string Path to the file to reveal
function M.RevealInNetrw(file_path)
  if vim.bo.filetype ~= "netrw" then
    M.NetrwReveal()
    return
  end

  if not vim.fn.filereadable(file_path) then
    return
  end

  local filename = vim.fn.fnamemodify(file_path, ":t")

  local ok = pcall(function()
    vim.fn.setreg("/", filename)
    vim.cmd("silent normal! n")
  end)

  if not ok then
    vim.cmd("silent nohlsearch")
    return
  end

  vim.cmd("silent nohlsearch")
  vim.cmd("normal! zz")
end

function M.NetrwLastBuffer()
  local alt_bufnr = vim.fn.bufnr("#")

  -- Check if alternate buffer exists AND is valid
  if alt_bufnr == -1 or not vim.api.nvim_buf_is_valid(alt_bufnr) then
    return -- Silently fail if no alternate buffer or buffer is invalid
  end

  local current_filetype = vim.bo.filetype
  local previous_file = vim.fn.expand("%:p") -- Store current file before switching

  if current_filetype == "netrw" then
    -- From netrw: just switch to alternate buffer (usually a regular file)
    vim.cmd("buffer #")
  else
    -- From regular file: use edit to ensure buffer appears in buffer list if closed
    vim.cmd("edit #")

    -- If we switched TO netrw and came FROM a file, reveal that file
    if vim.bo.filetype == "netrw" and previous_file ~= "" then
      require("netrw-preview.utils").RevealInNetrw(previous_file)
    end
  end
end

return M
