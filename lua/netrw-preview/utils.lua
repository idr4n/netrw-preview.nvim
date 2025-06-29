---@class NetrwPreview.Utils
local M = {}

local preview = require("netrw-preview.preview")

-- These will be set from current buffer when netrw is opened
---@type integer?
M.current_bufnr = nil
---@type integer?
M.alt_buffer = nil

-- Track netrw split state
---@type table<integer, boolean> Buffer number -> was opened in split
M.netrw_split_state = {}

---Get the absolute path of the item under cursor in netrw
---@return string Absolute path of the current item
function M.get_absolute_path()
  return vim.fn["netrw#Call"]("NetrwFile", vim.fn["netrw#Call"]("NetrwGetWord"))
end

---Get the relative path of the item under cursor in netrw
---@return string Relative path of the current item
function M.get_relative_path()
  local absolute_path = M.get_absolute_path()
  return vim.fn.fnamemodify(absolute_path, ":.")
end

---Close all unmodified "No Name" buffers
local function close_empty_buffers()
  local buffers = vim.api.nvim_list_bufs()

  for _, bufnr in ipairs(buffers) do
    -- Check if buffer is valid and loaded
    if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) then
      -- Check if buffer has no name and is not modified
      local bufname = vim.api.nvim_buf_get_name(bufnr)
      local is_modified = vim.bo[bufnr].modified

      if bufname == "" and not is_modified then
        vim.api.nvim_buf_delete(bufnr, {})
      end
    end
  end
end

---Check if any netrw window is currently open
---@return boolean True if netrw is open in any window
local function is_netrw_open()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == "netrw" then
      return true
    end
  end
  return false
end

---Reveal current file in netrw file explorer
---Opens netrw in the directory of the current file and highlights it
---@param use_lexplore? boolean Whether to use Lexplore instead of Explore (default: false)
function M.NetrwReveal(use_lexplore)
  vim.schedule(function()
    close_empty_buffers()
  end)

  vim.g.netrw_chgwin = -1
  use_lexplore = use_lexplore or false

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
    if use_lexplore then
      vim.cmd("silent Lexplore")
    else
      vim.cmd("silent Explore")
    end
    return
  end

  M.current_bufnr = vim.fn.bufnr()

  local filename = vim.fn.expand("%:t")
  local filepath = vim.fn.expand("%:p:h")

  -- Use silent commands to prevent history pollution
  vim.fn.setreg("/", filename)

  -- Track window count before opening netrw
  local win_count_before = #vim.api.nvim_list_wins()

  if use_lexplore then
    vim.cmd("silent Lexplore " .. vim.fn.fnameescape(filepath))
  else
    vim.cmd("silent Explore " .. vim.fn.fnameescape(filepath))
  end

  -- Track window count after opening netrw and store split state
  local win_count_after = #vim.api.nvim_list_wins()
  local netrw_buf = vim.api.nvim_get_current_buf()

  -- If window count increased, netrw was opened in a split
  M.netrw_split_state[netrw_buf] = win_count_after > win_count_before

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
---@param use_lexplore? boolean Whether to use Lexplore instead of Explore (default: false)
function M.RevealInNetrw(path, use_lexplore)
  use_lexplore = use_lexplore or false

  -- If no path provided, use current file behavior
  if not path or path == "" then
    if vim.bo.filetype ~= "netrw" then
      M.NetrwReveal(use_lexplore)
    end
    return
  end

  vim.schedule(function()
    close_empty_buffers()
  end)

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
    target_dir = path
    target_file = nil
  else
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

  -- Track window count before opening netrw
  local win_count_before = #vim.api.nvim_list_wins()

  -- Open netrw in target directory with Lexplore or Explore
  if use_lexplore then
    vim.cmd("silent Lexplore " .. vim.fn.fnameescape(target_dir))
  else
    vim.cmd("silent Explore " .. vim.fn.fnameescape(target_dir))
  end

  -- Track window count after opening netrw and store split state
  local win_count_after = #vim.api.nvim_list_wins()
  local netrw_buf = vim.api.nvim_get_current_buf()

  -- If window count increased, netrw was opened in a split
  M.netrw_split_state[netrw_buf] = win_count_after > win_count_before

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
    -- disable preview
    preview.disable_preview({ delete_buffer = true })
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

---Check if the current netrw selection is a directory
---@return boolean True if the current selection is a directory
local function is_current_selection_directory()
  local line = vim.api.nvim_get_current_line()
  local name = line:gsub("%s+$", "") -- Trim trailing whitespace

  -- Skip special entries
  if name == "" or name == "." or name == ".." then
    return true -- Treat as directory for navigation purposes
  end

  -- Check if line ends with "/" (netrw directory indicator)
  if name:match("/$") then
    return true
  end

  -- Get absolute path and check if it's a directory
  local absolute_path = M.get_absolute_path()
  return vim.fn.isdirectory(absolute_path) == 1
end

---Smart enter directory/file function
---@return nil
function M.smart_enter()
  if is_current_selection_directory() then
    vim.api.nvim_input("<Plug>NetrwLocalBrowseCheck")
  else
    local selected_file_path = vim.fn.fnamemodify(M.get_absolute_path(), ":p")
    local ok, current_file_path = pcall(vim.api.nvim_buf_get_name, M.current_bufnr)

    -- It's a file, open it (disable preview first)
    preview.disable_preview({ delete_buffer = true })
    vim.api.nvim_input("<Plug>NetrwLocalBrowseCheck")

    if not ok then
      return
    end

    -- preserve alternate buffer context
    current_file_path = vim.fn.fnamemodify(current_file_path, ":p")

    if selected_file_path == current_file_path then
      if M.alt_buffer and vim.api.nvim_buf_is_valid(M.alt_buffer) then
        vim.schedule(function()
          vim.fn.setreg("#", M.alt_buffer)
        end)
      end
    else
      if M.current_bufnr and vim.api.nvim_buf_is_valid(M.current_bufnr) then
        vim.schedule(function()
          vim.fn.setreg("#", M.current_bufnr)
        end)
      end
    end
  end
end

---Close netrw and return to previous buffer
---@return nil
function M.close_netrw()
  vim.schedule(function()
    close_empty_buffers()
  end)

  preview.disable_preview({ delete_buffer = true })

  local current_ft = vim.bo.filetype

  if current_ft == "netrw" then
    local netrw_buf = vim.api.nvim_get_current_buf()
    local was_split = M.netrw_split_state[netrw_buf]

    if was_split then
      vim.cmd("bdelete")
    end

    if vim.api.nvim_buf_is_valid(M.current_bufnr or -1) then
      vim.api.nvim_set_current_buf(M.current_bufnr)
    end

    -- Clean up tracking info
    M.netrw_split_state[netrw_buf] = nil
  else
    -- We're NOT in netrw buffer (e.g., called from toggle)
    local netrw_buffers = {}
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "netrw" then
        table.insert(netrw_buffers, buf)
      end
    end

    -- Close all netrw buffers
    for _, buf in ipairs(netrw_buffers) do
      local was_split = M.netrw_split_state[buf]

      if was_split then
        vim.api.nvim_buf_delete(buf, { force = false })
      else
        -- Find window with this buffer and quit it
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          if vim.api.nvim_win_get_buf(win) == buf then
            if vim.api.nvim_buf_is_valid(M.current_bufnr or -1) then
              vim.api.nvim_win_set_buf(win, M.current_bufnr)
            end
            break
          end
        end
      end

      -- Clean up tracking info
      M.netrw_split_state[buf] = nil
    end
  end

  -- Set alternate buffer regardless of which path we took
  if M.alt_buffer and vim.api.nvim_buf_is_valid(M.alt_buffer) then
    vim.fn.setreg("#", M.alt_buffer)
  elseif M.current_bufnr and vim.api.nvim_buf_is_valid(M.current_bufnr) then
    vim.fn.setreg("#", M.current_bufnr)
  end
end

---Toggle NetrwReveal or NetrwRevealLex (open netrw or close if already open)
---@param lexplore? boolean Whether to use Lexplore instead of Explore (default: false)
function M.toggle_reveal(lexplore)
  lexplore = lexplore or false
  if is_netrw_open() then
    require("netrw-preview.utils").close_netrw()
  else
    if lexplore then
      M.NetrwReveal(true)
    else
      M.NetrwReveal()
    end
  end
end

return M
