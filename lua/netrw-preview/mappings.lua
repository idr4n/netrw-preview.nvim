---@class NetrwPreview.MappingsModule
local M = {}

local utils = require("netrw-preview.utils")
local history = require("netrw-preview.history")
local reveal = require("netrw-preview.reveal")

---Check if a mapping value is valid (not nil and not empty string)
---@param value any The mapping value to check
---@return boolean True if the mapping should be created
local function is_valid_mapping(value)
  return value and value ~= ""
end

---Apply key mappings handling both individual keys and arrays of keys
---@param mapping_value string|string[]? The key or keys to map
---@param callback string|function The rhs or function to execute when key is pressed
---@param opts table Options for vim.keymap.set
---@param mode string|string[]? Mode "short-name", or a list thereof.
---@return nil
local function apply_mapping(mapping_value, callback, opts, mode)
  mode = mode or "n"
  -- For a single string mapping
  if type(mapping_value) == "string" then
    if is_valid_mapping(mapping_value) then
      vim.keymap.set(mode, mapping_value, callback, opts)
    end
    return
  end

  -- For an array of mappings
  if type(mapping_value) == "table" then
    for _, key in ipairs(mapping_value) do
      if is_valid_mapping(key) then
        vim.keymap.set(mode, key, callback, opts)
      end
    end
    return
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

  -- Toggle preview mapping - uses the main module's toggle function
  apply_mapping(config.mappings.toggle_preview, function()
    require("netrw-preview").toggle_preview()
  end, {
    buffer = true,
    noremap = true,
    silent = true,
    desc = "Toggle netrw preview",
  })

  -- Close netrw mappings - uses reveal module
  apply_mapping(config.mappings.close_netrw, reveal.close, {
    buffer = true,
    nowait = true,
    silent = true,
    desc = "Close netrw",
  })

  -- Parent directory mapping
  apply_mapping(config.mappings.parent_dir, function()
    history.add_path_to_history()
    vim.api.nvim_input("<Plug>NetrwBrowseUpDir")
  end, {
    buffer = true,
    silent = true,
    desc = "Parent directory",
  })

  -- Smart enter directory/file mapping - uses reveal module
  apply_mapping(config.mappings.enter_dir, reveal.smart_enter, {
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

          vim.cmd("NetrwRevealFile " .. vim.fn.fnameescape(final_path))
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
    local relative_path = utils.get_relative_path()
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
    local absolute_path = utils.get_absolute_path()
    vim.fn.setreg("+", absolute_path)
    print("Copied: " .. absolute_path)
  end, {
    buffer = true,
    desc = "Yank absolute path",
  })

  -- Mark files in visual mode
  apply_mapping(
    config.mappings.mark_files_visual,
    ":normal mf<cr>",
    { buffer = true, desc = "Mark selected files in visual mode" },
    "x"
  )

  -- Unmark files in visual mode
  apply_mapping(
    config.mappings.unmark_files_visual,
    ":normal mF<cr>",
    { buffer = true, desc = "Unmark selected files in visual mode" },
    "x"
  )

  apply_mapping(config.mappings.go_back, history.go_back, {
    buffer = true,
    silent = true,
    desc = "Go back in netrw history",
  })

  apply_mapping(config.mappings.go_forward, history.go_forward, {
    buffer = true,
    silent = true,
    desc = "Go forward in netrw history",
  })

  apply_mapping(config.mappings.go_first, history.go_first, {
    buffer = true,
    silent = true,
    desc = "Go to first entry in netrw history",
  })

  apply_mapping(config.mappings.go_last, history.go_last, {
    buffer = true,
    silent = true,
    desc = "Go to last entry in netrw history",
  })

  apply_mapping(",h", history.print_history, {
    buffer = true,
    silent = true,
    desc = "Print netrw history",
  })
end

return M
