---@class NetrwPreview.Utils
local M = {}

---Check if netrw is currently in tree view mode
---@return boolean True if in tree view mode
local function is_tree_view()
  -- First check window-local netrw_liststyle
  if vim.w.netrw_liststyle ~= nil then
    return vim.w.netrw_liststyle == 3
  end

  -- Then check buffer-local netrw_liststyle
  if vim.b.netrw_liststyle ~= nil then
    return vim.b.netrw_liststyle == 3
  end

  -- Fallback to global setting
  return vim.g.netrw_liststyle == 3
end

---Check if the current netrw selection is a directory
---@return boolean True if the current selection is a directory
function M.is_directory(path)
  -- Skip special entries
  if path == "" or path == "." or path == ".." then
    return true -- Treat as directory for navigation purposes
  end

  -- Check if line ends with "/" (netrw directory indicator)
  if path:match("/$") then
    return true
  end

  return vim.fn.isdirectory(path) == 1
end

---Check if we're in tree view and currently on a directory
---@return boolean True if in tree view and on a directory
function M.is_tree_view_directory()
  if not is_tree_view() then
    return false
  end

  -- Get the word under cursor using netrw's functions
  local word = vim.fn["netrw#Call"]("NetrwGetWord")
  local path = vim.fn["netrw#Call"]("NetrwFile", word)

  if path and path ~= "" then
    path = vim.fn.fnamemodify(path, ":p")
    return M.is_directory(path)
  end

  return false
end

---Get the absolute path of the item under cursor in netrw
---@return string Absolute path of the current item
function M.get_absolute_path()
  -- Always use netrw's internal functions for proper handling of special characters
  local word = vim.fn["netrw#Call"]("NetrwGetWord")
  local path = vim.fn["netrw#Call"]("NetrwFile", word)

  if path and path ~= "" then
    path = vim.fn.fnamemodify(path, ":p")
  end

  -- In tree view, disable directory previews to avoid path duplication issues
  if is_tree_view() and path and path ~= "" then
    if M.is_directory(path) then
      return ""
    end
  end

  return path or ""
end

---Get the relative path of the item under cursor in netrw
---@return string Relative path of the current item
function M.get_relative_path()
  local absolute_path = M.get_absolute_path()
  return vim.fn.fnamemodify(absolute_path, ":.")
end

return M
