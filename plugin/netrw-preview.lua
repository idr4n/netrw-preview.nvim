-- Prevent loading twice
if vim.g.loaded_netrw_preview then
  return
end
---@type boolean
vim.g.loaded_netrw_preview = true

-- Create user commands for direct access
vim.api.nvim_create_user_command("NetrwPreviewToggle", function()
  require("netrw-preview").toggle_preview()
end, { desc = "Toggle netrw preview" })

vim.api.nvim_create_user_command("NetrwPreviewEnable", function()
  require("netrw-preview").enable_preview()
end, { desc = "Enable netrw preview" })

vim.api.nvim_create_user_command("NetrwPreviewDisable", function()
  require("netrw-preview").disable_preview()
end, { desc = "Disable netrw preview" })

vim.api.nvim_create_user_command("NetrwReveal", function()
  require("netrw-preview").reveal()
end, { desc = "Reveal current file in netrw" })

vim.api.nvim_create_user_command("NetrwRevealFile", function(opts)
  local file_path = opts.args ~= "" and opts.args or vim.fn.expand("%:p")
  require("netrw-preview").reveal_file(file_path)
end, {
  desc = "Reveal specified directory or file in netrw",
  nargs = "?",
  complete = "file",
})

vim.api.nvim_create_user_command("NetrwRevealLex", function()
  require("netrw-preview").reveal_lex()
end, { desc = "Reveal current file in Lexplore" })

vim.api.nvim_create_user_command("NetrwRevealFileLex", function(opts)
  local file_path = opts.args ~= "" and opts.args or vim.fn.expand("%:p")
  require("netrw-preview").reveal_file_lex(file_path)
end, {
  desc = "Reveal specified directory or file in Lexplore",
  nargs = "?",
  complete = "file",
})

vim.api.nvim_create_user_command("NetrwLastBuffer", function()
  require("netrw-preview.utils").NetrwLastBuffer()
end, { desc = "Go to alternate buffer (with netrw reveal)" })

vim.api.nvim_create_user_command("NetrwRevealToggle", function()
  require("netrw-preview").reveal_file_toggle()
end, { desc = "Toggle Netrw Reveal (Explore)" })

vim.api.nvim_create_user_command("NetrwRevealLexToggle", function()
  require("netrw-preview").reveal_file_lex_toggle()
end, { desc = "Toggle Netrw Reveal (Lexplore)" })
