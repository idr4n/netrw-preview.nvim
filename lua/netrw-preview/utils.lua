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

---Reveal a specific file or directory in netrw
---@param path? string Path to the file or directory to reveal (defaults to current file)
function M.RevealInNetrw(path)
  -- If no path provided, use current file behavior
  if not path or path == "" then
    if vim.bo.filetype ~= "netrw" then
      M.NetrwReveal()
    end
    return
  end

  -- Expand and normalize the path
  path = vim.fn.fnamemodify(path, ":p")

  -- Check if path exists
  if not vim.fn.filereadable(path) and not vim.fn.isdirectory(path) then
    vim.notify("Path does not exist: " .. path, vim.log.levels.WARN)
    return
  end

  local target_dir
  local target_file

  if vim.fn.isdirectory(path) == 1 then
    -- It's a directory - just open netrw there
    target_dir = path
    target_file = nil
  else
    -- It's a file - open netrw in containing directory and focus on file
    target_dir = vim.fn.fnamemodify(path, ":h")
    target_file = vim.fn.fnamemodify(path, ":t")
  end

  -- If not in netrw, capture buffer info and open netrw in target directory
  if vim.bo.filetype ~= "netrw" then
    local alt_bufnr = vim.fn.bufnr("#")

    -- Capture buffer info like NetrwReveal does
    if alt_bufnr ~= -1 and vim.api.nvim_buf_is_valid(alt_bufnr) and vim.bo[alt_bufnr].buflisted then
      M.alt_buffer = alt_bufnr
    else
      M.alt_buffer = nil
    end

    M.current_bufnr = vim.fn.bufnr()
  end

  -- Open netrw in target directory
  vim.cmd("silent Explore " .. vim.fn.fnameescape(target_dir))

  if target_file then
    local ok = pcall(function()
      vim.fn.setreg("/", target_file)
      vim.cmd("silent normal! n")
    end)

    if not ok then
      vim.cmd("silent nohlsearch")
      return
    end

    vim.cmd("silent nohlsearch")
    vim.cmd("normal! zz")
  end
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
      M.RevealInNetrw(previous_file)
    end
  end
end

return M
