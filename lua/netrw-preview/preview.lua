---@class NetrwPreview.Preview
---@field preview_buf integer?
---@field preview_enabled boolean
---@field augroup integer?
---@field original_buffer_in_target_window integer?
---@field preview_created_split boolean
---@field current_node_path string?
---@field config NetrwPreview.Config
local Preview = {}

local utils = require("netrw-preview.utils")

---Create a new preview instance
---@param opts? {config?: NetrwPreview.Config}
---@return NetrwPreview.Preview
function Preview.create(opts)
  opts = opts or {}

  return setmetatable({
    preview_buf = nil,
    preview_enabled = false,
    augroup = nil,
    original_buffer_in_target_window = nil,
    preview_created_split = false,
    current_node_path = nil,
    config = opts.config or require("netrw-preview.config").options,
  }, { __index = Preview })
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

---Check if preview instance is valid
---@return boolean
function Preview:is_valid()
  return self.preview_buf ~= nil and vim.api.nvim_buf_is_valid(self.preview_buf) and self.preview_enabled
end

---Check if preview is currently enabled
---@return boolean True if preview is enabled
function Preview:is_preview_enabled()
  return self.preview_enabled
end

---Get the preview buffer handle
---@return integer? Buffer handle or nil if not created
function Preview:get_preview_buffer()
  return self.preview_buf
end

---Open the preview window with configured layout and size, and smart window reuse
function Preview:open_preview_window()
  if not self.preview_buf or not vim.api.nvim_buf_is_valid(self.preview_buf) then
    return
  end

  local current_win = vim.api.nvim_get_current_win()
  local cursor_pos = vim.api.nvim_win_get_cursor(current_win)
  local wins = vim.api.nvim_list_wins()

  -- Check if preview is already open somewhere
  for _, win in ipairs(wins) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == self.preview_buf then
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
    self.preview_created_split = true -- Track that we created a split
    self.original_buffer_in_target_window = nil -- No original buffer to restore

    if self.config.preview_layout == "horizontal" then
      if self.config.preview_side == "below" then
        vim.cmd("leftabove split")
      else
        vim.cmd("rightbelow split")
      end
    else
      if self.config.preview_side == "left" then
        vim.cmd("leftabove vsplit")
      else
        vim.cmd("rightbelow vsplit")
      end
    end

    local preview_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(preview_win, self.preview_buf)

    -- Set window size
    if self.config.preview_layout == "horizontal" then
      local total_height = vim.o.lines
      local preview_win_height = math.floor(total_height * (self.config.preview_height / 100))
      vim.api.nvim_win_set_height(preview_win, preview_win_height)
    else
      local total_width = vim.o.columns
      local preview_win_width = math.floor(total_width * (self.config.preview_width / 100))
      vim.api.nvim_win_set_width(preview_win, preview_win_width)
    end

    vim.cmd("wincmd p") -- Return focus to netrw
  else
    -- Multiple windows: reuse existing window
    self.preview_created_split = false -- Track that we reused a window

    local preview_win = nil
    for _, win in ipairs(wins) do
      if win ~= current_win and is_suitable_window(win) then
        preview_win = win
        break
      end
    end

    if preview_win then
      -- Store the original buffer in target window
      self.original_buffer_in_target_window = vim.api.nvim_win_get_buf(preview_win)
      vim.api.nvim_win_set_buf(preview_win, self.preview_buf)
      vim.api.nvim_set_current_win(current_win)
    end
  end

  vim.api.nvim_win_set_cursor(current_win, cursor_pos)
end

---Display message for directory in tree view
---@private
function Preview:_display_tree_view_directory_message()
  vim.api.nvim_buf_set_lines(self.preview_buf, 0, -1, false, {
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
    "              DIRECTORY IN TREE VIEW",
    "",
    "• Use Enter to expand/collapse directory",
    "• Navigate with j/k or arrow keys",
    "• Files inside will show preview when selected",
    "",
    "Note: Directory preview is disabled in tree",
    "view to avoid path parsing issues",
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
  })
  vim.bo[self.preview_buf].filetype = ""
end

---Display message for binary files
---@private
---@param path string Path to the binary file
function Preview:_display_binary_file_message(path)
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

  vim.api.nvim_buf_set_lines(self.preview_buf, 0, -1, false, {
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
    "                BINARY FILE",
    "              Preview not available",
    "",
    "File: " .. vim.fn.fnamemodify(path, ":t"),
    "Size: " .. size_str,
    "Type: Binary/Non-text file",
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
  })
  vim.bo[self.preview_buf].filetype = ""
end

---Display directory contents
---@private
---@param path string Path to the directory
function Preview:_display_directory_contents(path)
  local listing = vim.fn.glob(path .. "/*", false, true)
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

  vim.api.nvim_buf_set_lines(self.preview_buf, 0, -1, false, lines)
  vim.bo[self.preview_buf].filetype = "netrw"
end

---Display text file contents
---@private
---@param path string Path to the text file
function Preview:_display_text_file_contents(path)
  local success, lines = pcall(vim.fn.readfile, path)
  if success and lines then
    lines = split_lines_with_newlines(lines)

    -- Limit preview to reasonable number of lines for performance
    if #lines > 500 then
      lines = vim.list_slice(lines, 1, 500)
      table.insert(lines, "")
      table.insert(lines, "... (file truncated for preview)")
    end

    vim.api.nvim_buf_set_lines(self.preview_buf, 0, -1, false, lines)
    local ft = vim.filetype.match({ filename = path })
    if ft then
      vim.bo[self.preview_buf].filetype = ft
    end
  else
    vim.api.nvim_buf_set_lines(self.preview_buf, 0, -1, false, {
      "Error reading file: " .. path,
      "This file may be corrupted or inaccessible.",
    })
    vim.bo[self.preview_buf].filetype = ""
  end
end

---Update the preview content based on cursor position in netrw
function Preview:update_preview()
  if not self.preview_enabled then
    return
  end

  if not self.preview_buf or not vim.api.nvim_buf_is_valid(self.preview_buf) then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].filetype ~= "netrw" then
    return
  end

  local path = utils.get_absolute_path()

  -- Handle tree view directory case
  if (not path or path == "") and utils.is_tree_view_directory() then
    vim.bo[self.preview_buf].modifiable = true
    self:_display_tree_view_directory_message()
    vim.bo[self.preview_buf].modifiable = false
    return
  end

  if not path or path == "" then
    return
  end

  -- Store current node path for comparison
  self.current_node_path = path
  vim.bo[self.preview_buf].modifiable = true

  local is_dir = vim.fn.isdirectory(path) == 1

  if is_dir then
    self:_display_directory_contents(path)
  else
    -- Check if file is readable
    if vim.fn.filereadable(path) ~= 1 then
      vim.api.nvim_buf_set_lines(self.preview_buf, 0, -1, false, { "Cannot read file: " .. path })
      vim.bo[self.preview_buf].filetype = ""
      vim.bo[self.preview_buf].modifiable = false
      return
    end

    -- Check if file is binary
    if is_binary_file(path) then
      self:_display_binary_file_message(path)
    else
      self:_display_text_file_contents(path)
    end
  end

  vim.bo[self.preview_buf].modifiable = false
end

---Setup autocommands for this preview instance
function Preview:setup_autocmds()
  if not self.augroup then
    return
  end

  -- Set up autocommands
  vim.api.nvim_create_autocmd("BufEnter", {
    group = self.augroup,
    pattern = "*",
    callback = function()
      if vim.bo.filetype == "netrw" then
        self:open_preview_window()
      end
    end,
  })

  vim.api.nvim_create_autocmd("CursorMoved", {
    group = self.augroup,
    pattern = "*",
    callback = function()
      if vim.bo.filetype == "netrw" then
        self:update_preview()
      end
    end,
  })
end

---Enable preview functionality
function Preview:enable_preview()
  if self.preview_enabled then
    return
  end
  self.preview_enabled = true

  -- Create or reuse the preview buffer
  if not self.preview_buf or not vim.api.nvim_buf_is_valid(self.preview_buf) then
    self.preview_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(self.preview_buf, "NetrwPreview")
    vim.bo[self.preview_buf].buftype = "nofile"
    vim.bo[self.preview_buf].bufhidden = "hide"
    vim.bo[self.preview_buf].swapfile = false
  end

  -- Create autocommand group
  self.augroup = vim.api.nvim_create_augroup("NetrwPreviewInstance_" .. self.preview_buf, { clear = true })

  -- Set up autocommands
  self:setup_autocmds()

  -- If currently in netrw, open the preview window and update
  if vim.bo.filetype == "netrw" then
    self:open_preview_window()
    self:update_preview()
  end
end

---Close the preview window
function Preview:close_preview_window()
  local wins = vim.api.nvim_list_wins()

  if self.preview_created_split then
    -- Single window mode: close the split entirely
    for _, win in ipairs(wins) do
      if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == self.preview_buf then
        vim.api.nvim_win_close(win, false)
        break
      end
    end
  else
    -- Multiple window mode: restore original buffer
    for _, win in ipairs(wins) do
      if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == self.preview_buf then
        if
          self.original_buffer_in_target_window and vim.api.nvim_buf_is_valid(self.original_buffer_in_target_window)
        then
          vim.api.nvim_win_set_buf(win, self.original_buffer_in_target_window)
        else
          local empty_buf = vim.api.nvim_create_buf(true, false)
          vim.api.nvim_win_set_buf(win, empty_buf)
        end
        break
      end
    end
  end

  -- Reset state
  self.preview_created_split = false
  self.original_buffer_in_target_window = nil
end

---Disable preview functionality
---@param opts? {delete_buffer?: boolean} Options for disabling preview
function Preview:disable_preview(opts)
  opts = opts or { delete_buffer = false }

  if not self.preview_enabled then
    return
  end

  self.preview_enabled = false

  -- Clear autocommands for this group only
  if self.augroup then
    vim.api.nvim_clear_autocmds({ group = self.augroup })
    vim.api.nvim_del_augroup_by_id(self.augroup)
    self.augroup = nil
  end

  -- Close preview window
  self:close_preview_window()

  if opts.delete_buffer and self.preview_buf and vim.api.nvim_buf_is_valid(self.preview_buf) then
    vim.api.nvim_buf_delete(self.preview_buf, { force = true })
    self.preview_buf = nil
  end

  -- Reset state
  self.current_node_path = nil
end

---Toggle preview functionality on/off
function Preview:toggle_preview()
  if self.preview_enabled then
    self:disable_preview()
  else
    self:enable_preview()
  end
end

-- Export the Preview class
local M = {}

---Create a new preview instance
---@param opts? {config?: NetrwPreview.Config}
---@return NetrwPreview.Preview
function M.create(opts)
  return Preview.create(opts)
end

return M
