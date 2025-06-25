local M = {}

---@class NetrwPreview.Config
---@field preview_width integer Preview window width percentage for vertical splits (default: 60)
---@field preview_height integer Preview window height percentage for horizontal splits (default: 60)
---@field preview_layout "vertical"|"horizontal" Layout orientation of preview window (default: "vertical")
---@field preview_side "left"|"right"|"above"|"below" Side to open preview window (default: "right")
---@field preview_enabled boolean Enable preview by default
---@field auto_open_netrw boolean Auto-open netrw when starting with no files (default: false)
---@field mappings NetrwPreview.MappingConfig Custom key mappings

---@class NetrwPreview.MappingConfig
---@field enabled boolean Enable default key mappings (default: true)
---@field toggle_preview string|string[]? Key(s) to toggle preview (default: "p", "", false or {} to disable)
---@field close_netrw string|string[]? Key(s) to close netrw (default: {"q", "gq", "<c-q>"}, "", false or {} to disable)
---@field parent_dir string|string[]? Key(s) to go to parent directory (default: "h", "", false or {} to disable)
---@field enter_dir string|string[]? Key(s) to enter directory (default: "l", "", false or {} to disable)
---@field insert_path string|string[]? Key(s) to insert relative path in command line (default: ".", "", false or {} to disable)
---@field yank_path string|string[]? Key(s) to yank absolute path (default: "Y", "", false or {} to disable)
---@field directory_mappings NetrwPreview.DirectoryMapping[]? Custom directory shortcuts

---@class NetrwPreview.DirectoryMapping
---@field key string The key binding for this directory
---@field path string|fun():string The directory path to navigate to (string or function returning string)
---@field desc string? Optional description for the mapping

---@type NetrwPreview.Config
M.defaults = {
  preview_width = 60,
  preview_height = 60,
  preview_layout = "vertical",
  preview_side = "right",
  preview_enabled = false,
  auto_open_netrw = false,
  mappings = {
    enabled = true,
    toggle_preview = "p",
    close_netrw = { "q", "gq", "<c-q>" },
    parent_dir = "h",
    enter_dir = "l",
    insert_path = ".",
    yank_path = "Y",
    directory_mappings = {
      { key = "~", path = "~", desc = "Home directory" },
    },
  },
}

---@type NetrwPreview.Config | {}
M.options = {}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
