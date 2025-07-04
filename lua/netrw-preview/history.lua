---@class NetrwPreview.History
local M = {}

---@class PathHistory
---@field position integer Current position in the history
---@field paths string[] List of file paths

-- Track netrw path history
---@type table<integer, PathHistory> Window ID -> path history
M.netrw_window_history = {}

-- Configuration
local MAX_HISTORY = 50

---Initialize history for a window
---@param win_id integer Window ID
function M.init_window_history(win_id)
  if not M.netrw_window_history[win_id] then
    M.netrw_window_history[win_id] = { position = 0, paths = {} }
  end
end

---Add path to history
---@param win_id integer Window ID
---@param path string Absolute path to add
function M.add_path(win_id, path)
  M.init_window_history(win_id)
  local history = M.netrw_window_history[win_id]

  -- Don't add if it's the same as the last entry
  if #history.paths > 0 and history.paths[#history.paths] == path then
    history.position = 0
    return
  end

  -- Slice history if follow different branch
  local pos = history.position
  if pos > 0 and pos <= #history.paths then
    local parent_curr = vim.fn.fnamemodify(history.paths[pos]:gsub("/$", ""), ":h")
    local parent_new = vim.fn.fnamemodify(path:gsub("/$", ""), ":h")

    local upper = parent_curr == parent_new and (pos - 1) or pos
    history.paths = vim.list_slice(history.paths, 1, upper)
  end

  history.position = 0
  table.insert(history.paths, path)

  -- Trim history if too long
  if #history.paths > MAX_HISTORY then
    history.paths = vim.list_slice(history.paths, #history.paths - MAX_HISTORY + 1)
  end
end

---Navigate backward in history
---@return nil
function M.go_back()
  local utils = require("netrw-preview.utils")
  local win_id = vim.api.nvim_get_current_win()
  local history = M.netrw_window_history[win_id]
  local sel_path = utils.get_absolute_path()

  if not history or #history.paths == 0 then
    print("No history available")
    return
  end

  local pos = history.position
  local target_pos = pos > 0 and (pos - 1) or #history.paths

  -- Add current path to history if at end
  if pos == 0 or pos == #history.paths then
    M.add_path(win_id, sel_path)
  end

  if target_pos < 1 then
    print("Already at oldest history entry")
    return
  end

  local path = history.paths[target_pos]
  if not path then
    print("No history available")
    return
  end

  -- Replace path in history if different
  if pos > 0 and sel_path ~= history.paths[pos] then
    -- print("dir:", vim.b.netrw_curdir)
    -- print("sel_path:", vim.fn.fnamemodify(sel_path, ":h"))
    -- print("equal:", vim.b.netrw_curdir == vim.fn.fnamemodify(sel_path, ":h"))
    if vim.b.netrw_curdir == vim.fn.fnamemodify(sel_path, ":h") then
      history.paths[pos] = sel_path
    end
  end

  -- print("(history " .. target_pos .. "/" .. #history.paths .. ")")
  utils.RevealInNetrw(vim.fn.fnameescape(path), false, true, false, true)
  history.position = target_pos
  -- M.print_history()
end

---Navigate forward in history
---@return nil
function M.go_forward()
  local utils = require("netrw-preview.utils")
  local win_id = vim.api.nvim_get_current_win()
  local history = M.netrw_window_history[win_id]
  local sel_path = utils.get_absolute_path()

  if not history or #history.paths == 0 then
    print("No history available")
    return
  end

  local pos = history.position
  local target_pos = pos > 0 and (pos + 1) or #history.paths

  if target_pos > #history.paths then
    print("Already at newest history entry")
    return
  end

  local path = history.paths[target_pos]
  if not path then
    print("No history available")
    return
  end

  -- Replace path in history if different
  if pos > 0 and sel_path ~= history.paths[pos] then
    if vim.b.netrw_curdir == vim.fn.fnamemodify(sel_path, ":h") then
      history.paths[pos] = sel_path
    end
  end

  -- print("(history " .. target_pos .. "/" .. #history.paths .. ")")
  utils.RevealInNetrw(vim.fn.fnameescape(path), false, true, false, true)
  history.position = target_pos
  -- M.print_history()
end

---Jump to first (oldest) entry in history
function M.go_first()
  local utils = require("netrw-preview.utils")
  local win_id = vim.api.nvim_get_current_win()
  local history = M.netrw_window_history[win_id]
  local sel_path = utils.get_absolute_path()

  if not history or #history.paths == 0 then
    print("No history available")
    return
  end

  local pos = history.position

  -- Add current path to history if at end
  if pos == 0 or pos == #history.paths then
    M.add_path(win_id, sel_path)
  end

  if pos == 1 then
    print("Already at first history entry")
    return
  end

  -- Replace path in history if different
  if pos > 0 and sel_path ~= history.paths[pos] then
    if vim.b.netrw_curdir == vim.fn.fnamemodify(sel_path, ":h") then
      history.paths[pos] = sel_path
    end
  end

  local path = history.paths[1]
  utils.RevealInNetrw(vim.fn.fnameescape(path), false, true, false, true)
  history.position = 1
end

---Jump to last (newest) entry in history
function M.go_last()
  local utils = require("netrw-preview.utils")
  local win_id = vim.api.nvim_get_current_win()
  local history = M.netrw_window_history[win_id]
  local sel_path = utils.get_absolute_path()

  if not history or #history.paths == 0 then
    print("No history available")
    return
  end

  local pos = history.position
  local cnt = #history.paths

  if pos == cnt then
    print("Already at last history entry")
    return
  end

  -- Replace path in history if different
  if pos > 0 and sel_path ~= history.paths[pos] then
    if vim.b.netrw_curdir == vim.fn.fnamemodify(sel_path, ":h") then
      history.paths[pos] = sel_path
    end
  end

  local path = history.paths[cnt]
  utils.RevealInNetrw(vim.fn.fnameescape(path), false, true, false, true)
  history.position = cnt
end

---Clear history for a window
---@param win_id integer Window ID
function M.clear_window_history(win_id)
  M.netrw_window_history[win_id] = { position = 0, paths = {} }
end

---Get current history state for debugging
---@param win_id integer Window ID
---@return table History information
function M.get_history_info(win_id)
  local history = M.netrw_window_history[win_id]
  if not history then
    return { count = 0, position = 0, paths = {} }
  end

  return {
    count = #history.paths,
    position = history.position,
    paths = vim.deepcopy(history.paths),
  }
end

---Print history for debugging
function M.print_history()
  local win_id = vim.api.nvim_get_current_win()
  local info = M.get_history_info(win_id)
  vim.print({
    window = win_id,
    history_count = info.count,
    position = info.position,
    paths = info.paths,
  })
end

return M
