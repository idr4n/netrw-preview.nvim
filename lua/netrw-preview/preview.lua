---@class NetrwPreview.Preview
local M = {}

---@type integer?
local preview_buf
---@type boolean
local preview_enabled = false
---@type integer
local augroup = vim.api.nvim_create_augroup("NetrwPreviewModule", { clear = true })

---Get configuration options dynamically
---@return NetrwPreview.Config
local function get_config()
  return require("netrw-preview.config").options
end

---Check if a file is binary by extension and content analysis
---@param filepath string Path to the file to check
---@return boolean True if file appears to be binary
local function is_binary_file(filepath)
  if vim.fn.filereadable(filepath) ~= 1 then
    return false
  end

  -- First, check by common binary file extensions as fallback
  local extension = vim.fn.fnamemodify(filepath, ":e"):lower()
  -- stylua: ignore
  ---@type string[]
  local binary_extensions = {
    -- Documents
    'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'odt', 'ods', 'odp',
    -- Images
    'jpg', 'jpeg', 'png', 'gif', 'bmp', 'tiff', 'webp', 'ico', 'svg',
    -- Audio/Video
    'mp3', 'mp4', 'avi', 'mkv', 'wav', 'flac', 'ogg', 'mov', 'wmv',
    -- Archives
    'zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'xz',
    -- Executables
    'exe', 'dll', 'so', 'dylib', 'bin', 'deb', 'rpm', 'dmg', 'pkg',
    -- Other binary formats
    'sqlite', 'db', 'class', 'jar', 'war'
  }

  if vim.tbl_contains(binary_extensions, extension) then
    return true
  end

  -- Try to read file content for NULL byte detection
  local success, file = pcall(io.open, filepath, "rb")
  if not success or not file then
    -- If io.open fails, try vim's readfile as alternative
    local read_success, lines = pcall(vim.fn.readfile, filepath, "b", 1)
    if read_success and lines and #lines > 0 then
      local content = table.concat(lines, "")
      return content:find("\0") ~= nil
    end
    return false
  end

  local chunk = file:read(1024)
  file:close()

  if chunk then
    -- Check for NULL byte (binary indicator)
    return chunk:find("\0") ~= nil
  end

  return false
end

---Split lines that may contain embedded newlines
---@param lines string[] Array of lines that may contain embedded newlines
---@return string[] Array of properly split lines
local function split_lines_with_newlines(lines)
  ---@type string[]
  local result = {}
  for _, line in ipairs(lines) do
    -- Split any lines that contain embedded newlines
    local split = vim.split(line, "\n", { plain = true })
    for _, subline in ipairs(split) do
      table.insert(result, subline)
    end
  end
  return result
end

-- Checks if a window is suitable for preview
---@param win integer Window handle/ID
---@return boolean Whether the window is suitable for preview
local function is_suitable_window(win)
  if not vim.api.nvim_win_is_valid(win) then
    return false
  end

  -- Skip floating windows (notifications, popups, etc.)
  local win_config = vim.api.nvim_win_get_config(win)
  if win_config.relative ~= "" then
    return false
  end

  -- Check buffer type of the window
  local buf = vim.api.nvim_win_get_buf(win)
  if not vim.api.nvim_buf_is_valid(buf) then
    return false
  end

  local buftype = vim.bo[buf].buftype
  -- Skip special buffer types
  if
    buftype == "nofile"
    or buftype == "quickfix"
    or buftype == "help"
    or buftype == "terminal"
    or buftype == "prompt"
  then
    return false
  end

  -- Skip very small windows (likely notifications)
  local win_height = vim.api.nvim_win_get_height(win)
  local win_width = vim.api.nvim_win_get_width(win)
  if win_height < 10 or win_width < 20 then
    return false
  end

  return true
end

-- Store the original buffer in target window before preview
local original_buffer_in_target_window = nil

-- Store whether we created a split or reused a window
local preview_created_split = false

---Open the preview window with configured layout and size, and smart window reuse
local function open_preview_window()
  if not preview_buf or not vim.api.nvim_buf_is_valid(preview_buf) then
    return
  end

  local current_win = vim.api.nvim_get_current_win()
  local cursor_pos = vim.api.nvim_win_get_cursor(current_win)
  local wins = vim.api.nvim_list_wins()
  local config = get_config()

  -- Check if preview is already open somewhere
  for _, win in ipairs(wins) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == preview_buf then
      return -- Preview window already open
    end
  end

  local num_windows = #wins

  local num_suitable_windows = 0
  for _, win in ipairs(wins) do
    if is_suitable_window(win) then
      num_suitable_windows = num_suitable_windows + 1
    end
  end

  if num_windows == 1 or num_suitable_windows == 1 then
    -- Only one window: create new split
    preview_created_split = true -- Track that we created a split
    original_buffer_in_target_window = nil -- No original buffer to restore

    if config.preview_layout == "horizontal" then
      if config.preview_side == "below" then
        vim.cmd("leftabove split")
      else
        vim.cmd("rightbelow split")
      end
    else
      if config.preview_side == "left" then
        vim.cmd("leftabove vsplit")
      else
        vim.cmd("rightbelow vsplit")
      end
    end

    local preview_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(preview_win, preview_buf)

    -- Set window size
    if config.preview_layout == "horizontal" then
      local total_height = vim.o.lines
      local preview_win_height = math.floor(total_height * (config.preview_height / 100))
      vim.api.nvim_win_set_height(preview_win, preview_win_height)
    else
      local total_width = vim.o.columns
      local preview_win_width = math.floor(total_width * (config.preview_width / 100))
      vim.api.nvim_win_set_width(preview_win, preview_win_width)
    end

    vim.cmd("wincmd p") -- Return focus to netrw
  else
    -- Multiple windows: reuse existing window
    preview_created_split = false -- Track that we reused a window

    local preview_win = nil
    for _, win in ipairs(wins) do
      if win ~= current_win and is_suitable_window(win) then
        preview_win = win
        break
      end
    end

    if preview_win then
      -- Store the original buffer in target window
      original_buffer_in_target_window = vim.api.nvim_win_get_buf(preview_win)
      vim.api.nvim_win_set_buf(preview_win, preview_buf)
      vim.api.nvim_set_current_win(current_win)
    end
  end

  vim.api.nvim_win_set_cursor(current_win, cursor_pos)
end

---Update the preview content based on cursor position in netrw
local function update_preview()
  if not preview_enabled then
    return
  end

  if not preview_buf or not vim.api.nvim_buf_is_valid(preview_buf) then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].filetype ~= "netrw" then
    return
  end

  local line = vim.api.nvim_get_current_line()
  local name = line:gsub("%s+$", "") -- Trim trailing whitespace

  if name == "" or name == "." or name == ".." then
    return
  end

  local is_dir = name:match("/$")
  if is_dir then
    name = name:sub(1, -2) -- Remove trailing '/' for directories
  end

  local path = vim.fn.fnamemodify(vim.b.netrw_curdir .. "/" .. name, ":p")

  vim.bo[preview_buf].modifiable = true

  if is_dir then
    -- Display directory contents
    ---@type string[]
    local listing = vim.fn.glob(path .. "/*", false, true)
    ---@type string[]
    local lines = {}
    for _, item in ipairs(listing) do
      local item_name = vim.fn.fnamemodify(item, ":t")
      if vim.fn.isdirectory(item) == 1 then
        item_name = item_name .. "/"
      end
      table.insert(lines, item_name)
    end

    -- Sort directories first, then files, both alphabetically
    table.sort(lines, function(a, b)
      local a_is_dir = a:sub(-1) == "/"
      local b_is_dir = b:sub(-1) == "/"
      if a_is_dir ~= b_is_dir then
        return a_is_dir
      else
        return a:lower() < b:lower()
      end
    end)

    vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, lines)
    vim.bo[preview_buf].filetype = "netrw"
  else
    -- Check if file is readable
    if vim.fn.filereadable(path) ~= 1 then
      vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, { "Cannot read file: " .. path })
      vim.bo[preview_buf].filetype = ""
      vim.bo[preview_buf].modifiable = false
      return
    end

    -- Check if file is binary
    if is_binary_file(path) then
      local file_size = vim.fn.getfsize(path)
      local size_str = ""
      if file_size >= 0 then
        if file_size >= 1048576 then
          size_str = string.format(" (%.1f MB)", file_size / 1048576)
        elseif file_size >= 1024 then
          size_str = string.format(" (%.1f KB)", file_size / 1024)
        else
          size_str = string.format(" (%d bytes)", file_size)
        end
      end

      vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, {
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
        "                BINARY FILE",
        "              Preview not available",
        "",
        "File: " .. vim.fn.fnamemodify(path, ":t"),
        "Size: " .. size_str,
        "Type: Binary/Non-text file",
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
      })
      vim.bo[preview_buf].filetype = ""
    else
      -- Display text file contents
      local success, lines = pcall(vim.fn.readfile, path)
      if success and lines then
        lines = split_lines_with_newlines(lines)

        -- Limit preview to reasonable number of lines for performance
        if #lines > 500 then
          lines = vim.list_slice(lines, 1, 500)
          table.insert(lines, "")
          table.insert(lines, "... (file truncated for preview)")
        end

        vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, lines)
        local ft = vim.filetype.match({ filename = path })
        if ft then
          vim.bo[preview_buf].filetype = ft
        end
      else
        vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, {
          "Error reading file: " .. path,
          "This file may be corrupted or inaccessible.",
        })
        vim.bo[preview_buf].filetype = ""
      end
    end
  end

  vim.bo[preview_buf].modifiable = false
end

---Enable preview functionality
function M.enable_preview()
  if preview_enabled then
    return
  end
  preview_enabled = true

  -- Create or reuse the preview buffer
  if not preview_buf or not vim.api.nvim_buf_is_valid(preview_buf) then
    preview_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(preview_buf, "NetrwPreview")
    vim.bo[preview_buf].buftype = "nofile"
    vim.bo[preview_buf].bufhidden = "hide"
    vim.bo[preview_buf].swapfile = false
  end

  -- Set up autocommands
  vim.api.nvim_create_autocmd("BufEnter", {
    group = augroup,
    pattern = "*",
    callback = function()
      if vim.bo.filetype == "netrw" then
        open_preview_window()
      end
    end,
  })

  vim.api.nvim_create_autocmd("CursorMoved", {
    group = augroup,
    pattern = "*",
    callback = function()
      if vim.bo.filetype == "netrw" then
        update_preview()
      end
    end,
  })

  -- If currently in netrw, open the preview window and update
  if vim.bo.filetype == "netrw" then
    open_preview_window()
    update_preview()
  end
end

---Disable preview functionality
---@param opts? {delete_buffer?: boolean} Options for disabling preview
function M.disable_preview(opts)
  opts = opts or { delete_buffer = false }

  if not preview_enabled then
    return
  end

  preview_enabled = false

  -- Clear autocommands for this group only
  vim.api.nvim_clear_autocmds({ group = augroup })

  local wins = vim.api.nvim_list_wins()

  if preview_created_split then
    -- Single window mode: close the split entirely
    for _, win in ipairs(wins) do
      if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == preview_buf then
        vim.api.nvim_win_close(win, false)
        break
      end
    end
  else
    -- Multiple window mode: restore original buffer
    for _, win in ipairs(wins) do
      if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == preview_buf then
        if original_buffer_in_target_window and vim.api.nvim_buf_is_valid(original_buffer_in_target_window) then
          vim.api.nvim_win_set_buf(win, original_buffer_in_target_window)
        else
          local empty_buf = vim.api.nvim_create_buf(true, false)
          vim.api.nvim_win_set_buf(win, empty_buf)
        end
        break
      end
    end
  end

  -- Reset state
  preview_created_split = false
  original_buffer_in_target_window = nil

  if opts.delete_buffer and preview_buf and vim.api.nvim_buf_is_valid(preview_buf) then
    vim.api.nvim_buf_delete(preview_buf, { force = true })
    preview_buf = nil
  end
end

---Toggle preview functionality on/off
function M.toggle_preview()
  if preview_enabled then
    M.disable_preview()
  else
    M.enable_preview()
  end
end

---Check if preview is currently enabled
---@return boolean True if preview is enabled
function M.is_preview_enabled()
  return preview_enabled
end

---Get the preview buffer handle
---@return integer? Buffer handle or nil if not created
function M.get_preview_buffer()
  return preview_buf
end

return M
