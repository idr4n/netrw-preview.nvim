---@class NetrwPreview.Utils
local M = {}

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

return M
