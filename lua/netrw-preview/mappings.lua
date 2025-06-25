---@class NetrwPreview.MappingsModule
local M = {}

local preview = require("netrw-preview.preview")
local utils = require("netrw-preview.utils")

---Get the absolute path of the item under cursor in netrw
---@return string Absolute path of the current item
local function get_absolute_path()
  return vim.fn["netrw#Call"]("NetrwFile", vim.fn["netrw#Call"]("NetrwGetWord"))
end

---Get the relative path of the item under cursor in netrw
---@return string Relative path of the current item
local function get_relative_path()
  local absolute_path = get_absolute_path()
  return vim.fn.fnamemodify(absolute_path, ":.")
end

---Check if a mapping value is valid (not nil and not empty string)
---@param value any The mapping value to check
---@return boolean True if the mapping should be created
local function is_valid_mapping(value)
  return value and value ~= ""
end

---Apply key mappings handling both individual keys and arrays of keys
---@param mapping_value string|string[]? The key or keys to map
---@param callback function The function to execute when key is pressed
---@param opts table Options for vim.keymap.set
---@return nil
local function apply_mapping(mapping_value, callback, opts)
  -- For a single string mapping
  if type(mapping_value) == "string" then
    if is_valid_mapping(mapping_value) then
      vim.keymap.set("n", mapping_value, callback, opts)
    end
    return
  end

  -- For an array of mappings
  if type(mapping_value) == "table" then
    for _, key in ipairs(mapping_value) do
      if is_valid_mapping(key) then
        vim.keymap.set("n", key, callback, opts)
      end
    end
    return
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
  local absolute_path = get_absolute_path()
  return vim.fn.isdirectory(absolute_path) == 1
end

---Smart enter directory/file function
---@return nil
local function smart_enter()
  if is_current_selection_directory() then
    vim.api.nvim_input("<CR>")
  else
    local selected_file_path = vim.fn.fnamemodify(get_absolute_path(), ":p")
    local ok, current_file_path = pcall(vim.api.nvim_buf_get_name, utils.current_bufnr)

    -- It's a file, open it
    vim.api.nvim_input("<CR>")

    if not ok then
      return
    end

    -- preserve alternate buffer context
    current_file_path = vim.fn.fnamemodify(current_file_path, ":p")

    if selected_file_path == current_file_path then
      if utils.alt_buffer and vim.api.nvim_buf_is_valid(utils.alt_buffer) then
        vim.schedule(function()
          vim.fn.setreg("#", utils.alt_buffer)
        end)
      end
    else
      if utils.current_bufnr and vim.api.nvim_buf_is_valid(utils.current_bufnr) then
        vim.schedule(function()
          vim.fn.setreg("#", utils.current_bufnr)
        end)
      end
    end
  end
end

---Close netrw and return to previous buffer
---@return nil
local function close_netrw()
  preview.disable_preview({ delete_buffer = true })

  vim.cmd("bdelete")

  if vim.api.nvim_buf_is_valid(utils.current_bufnr or -1) then
    vim.api.nvim_set_current_buf(utils.current_bufnr)
  end

  if utils.alt_buffer and vim.api.nvim_buf_is_valid(utils.alt_buffer) then
    vim.fn.setreg("#", utils.alt_buffer)
  elseif utils.current_bufnr and vim.api.nvim_buf_is_valid(utils.current_bufnr) then
    vim.fn.setreg("#", utils.current_bufnr)
  end
end

---Setup buffer-specific key mappings for netrw
---@return nil
function M.setup_buffer_mappings()
  local config = require("netrw-preview.config").options

  -- Early return if mappings are disabled
  if not config.mappings.enabled then
    return
  end

  -- Toggle preview mapping
  apply_mapping(config.mappings.toggle_preview, function()
    preview.toggle_preview()
  end, {
    buffer = true,
    noremap = true,
    silent = true,
    desc = "Toggle netrw preview",
  })

  -- Close netrw mappings
  apply_mapping(config.mappings.close_netrw, close_netrw, {
    buffer = true,
    nowait = true,
    silent = true,
    desc = "Close netrw",
  })

  -- Parent directory mapping
  apply_mapping(config.mappings.parent_dir, function()
    vim.api.nvim_input("-")
  end, {
    buffer = true,
    silent = true,
    desc = "Parent directory",
  })

  -- Smart enter directory/file mapping
  apply_mapping(config.mappings.enter_dir, smart_enter, {
    buffer = true,
    silent = true,
    desc = "Enter directory/file",
  })

  -- Directory mappings
  if config.mappings.directory_mappings then
    for _, dir_map in ipairs(config.mappings.directory_mappings) do
      if is_valid_mapping(dir_map.key) and dir_map.path then
        vim.keymap.set("n", dir_map.key, function()
          local path

          -- Handle both string and function paths
          if type(dir_map.path) == "function" then
            path = dir_map.path()
          else
            path = dir_map.path
          end

          -- Type assertion: tell LSP that path is definitely a string here
          ---@cast path string

          local final_path

          -- Handle relative paths
          if vim.bo.filetype == "netrw" and not vim.startswith(path, "/") and not vim.startswith(path, "~") then
            -- For relative paths in netrw, resolve relative to current netrw directory
            local netrw_dir = vim.b.netrw_curdir or vim.fn.getcwd()
            final_path = vim.fn.fnamemodify(netrw_dir .. "/" .. path, ":p")
          else
            -- For absolute paths or when not in netrw, use normal expansion
            final_path = vim.fn.expand(path)
          end

          vim.cmd("Explore " .. vim.fn.fnameescape(final_path))
        end, {
          buffer = true,
          silent = true,
          desc = dir_map.desc or ("Go to " .. (type(dir_map.path) == "string" and dir_map.path or "directory")),
        })
      end
    end
  end

  -- Insert path mapping
  apply_mapping(config.mappings.insert_path, function()
    local relative_path = get_relative_path()
    local text_to_insert = " " .. relative_path
    vim.fn.feedkeys(":" .. text_to_insert)
    local left_keys = vim.api.nvim_replace_termcodes(string.rep("<Left>", #text_to_insert), true, true, true)
    vim.fn.feedkeys(left_keys)
  end, {
    buffer = true,
    desc = "Insert relative path in command line",
  })

  -- Yank path mapping
  apply_mapping(config.mappings.yank_path, function()
    local absolute_path = get_absolute_path()
    vim.fn.setreg("+", absolute_path)
    print("Copied: " .. absolute_path)
  end, {
    buffer = true,
    desc = "Yank absolute path",
  })
end

return M
