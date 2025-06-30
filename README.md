# 🔎 netrw-preview.nvim

A powerful Neovim plugin that enhances the built-in **Netrw file explorer with live preview** functionality and improved keybindings.

> [!IMPORTANT]
> **Note**: this plugin is in early development and is going through a testing stage, so expect breaking changes.

https://github.com/user-attachments/assets/b1955ed9-7570-4434-853c-56260ab770ac

## Motivation

The main motivation to write this plugin was to add a **live preview** to Netrw similar to `oil.nvim` or `mini.files`. 

I find Netrw quite powerful with many useful features. Although I have used other alternatives over the years (e.g., `Nvimtree`, `Neo-tree`, `Oil.nvim`, `Mini.files`), I wanted to get comfortable using netrw since it is the built-in file manager in Neovim. However, despite its built-in preview functionality, it opens files you're previewing as actual buffers. This leaves numerous unwanted buffers open at the end of your session, which I find undesirable.

Along the way, I decided to also include other enhancements to improve my own workflow in Netrw, similar in some ways to `vim-vinegar` and `dirvish.vim`.

## ✨ Features

- **Live Preview**: Real-time preview of files and directories as you navigate
- **Flexible Preview Layout**: Choose vertical or horizontal splits with configurable positioning and sizing
- **Smart File Detection**: Automatically detects and handles non-text files with file size information
- **Smart Enter Navigation**: Intelligent file/directory opening with proper alternate buffer handling
- **Flexible Directory Shortcuts**: Create custom keybindings for frequently accessed directories
- **Dynamic Path Support**: Use functions for context-aware directory navigation
- **Multiple Key Support**: Assign multiple keys to the same action for maximum flexibility
- **Enhanced Navigation**: Improved keybindings for better netrw workflow
- **File Operations**: Quick path copying, insertion, and navigation utilities, ala `vim-vinager`
- **Reveal Functionality**: Jump to current file in netrw from any buffer
- **Command-Based Interface**: Use commands for flexible external mapping
- **Highly Configurable**: Customize preview window size and layout, keybindings, and behavior

## 📦 Installation

#### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "idr4n/netrw-preview.nvim",
  ft = "netrw",
  keys = {
    { ",,", "<cmd>NetrwRevealToggle<cr>", desc = "Toggle Netrw - Reveal" },
    { ",l", "<cmd>NetrwRevealLexToggle<cr>", desc = "Toggle Netrw (Lex) - Reveal" },
    { "ga", "<cmd>NetrwLastBuffer<cr>", desc = "Go to alternate buffer (with netrw reveal)" },
  },
  opts = {}
}
```

#### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "idr4n/netrw-preview.nvim",
  config = function()
    require("netrw-preview").setup()
  end
}
```

#### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'idr4n/netrw-preview.nvim'
```

Then add to your `init.lua`:
```lua
require("netrw-preview").setup()
```

## ⚙️ Configuration


<details>
<summary>📋 Default Configuration</summary>

<br>


```lua
require("netrw-preview").setup({
  -- Preview window width as percentage of total width (for vertical splits)
  preview_width = 60,

  -- Preview window height as percentage of total height (for horizontal splits)
  preview_height = 60,

  -- Preview window layout orientation
  preview_layout = "vertical", -- "vertical" or "horizontal"

  -- Side to open preview window
  preview_side = "right", -- "left" or "right" for vertical, "above" or "below" for horizontal

  -- Enable preview by default when entering netrw
  preview_enabled = false,

  -- Auto-open netrw on startup if no file is specified
  -- Note: Requires no lazy loading to take effect
  auto_open_netrw = false,

  -- Key mappings
  mappings = {
    -- Enable/disable all mappings
    enabled = true,

    -- Toggle preview window
    toggle_preview = "p",

    -- Keys to close netrw (multiple options)
    close_netrw = { "q", "gq", "<c-q>" },

    -- Navigate to parent directory
    parent_dir = "h",

    -- Enter directory/open file (smart enter)
    enter_dir = { "l", "<cr>" },

    -- Insert relative path in command line
    insert_path = ".",

    -- Yank absolute path to clipboard
    yank_path = "Y",

    -- Custom directory shortcuts
    directory_mappings = {
      { key = "~", path = "~", desc = "Home directory" },
    },
  }
})
```

</details>


### 🔧 Flexible Key Mappings

All mappings support both single keys and multiple keys for the same action:

```lua
require("netrw-preview").setup({
  mappings = {
    -- Single key
    toggle_preview = "p",

    -- Multiple keys for same action
    close_netrw = { "q", "gq", "<c-q>", "<esc>" },
    parent_dir = { "h", "<BS" },
    enter_dir = { "l", "<CR>" },

    -- Disable with {}, empty string or false
    yank_path = {},         -- Disabled
    insert_path = "",       -- Also disabled
  }
})
```


### Example Custom Configuration

```lua
require("netrw-preview").setup({
  preview_width = 70,           -- Wider preview window (vertical splits)
  preview_height = 30,          -- Preview height (horizontal splits)
  preview_layout = "horizontal",-- Use horizontal split
  preview_side = "below",       -- Preview below netrw
  preview_enabled = true,       -- Auto-enable preview
  mappings = {
    toggle_preview = "<space>",
    close_netrw = { "q", "<Esc>" },
    yank_path = "yy",
    last_buffer = "",           -- diabled mapping, also false or {}
    directory_mappings = {
      { key = "~", path = "~", desc = "Home directory" },
      { key = "gd", path = "~/Downloads", desc = "Downloads directory" },
      -- relative path
      { key = "gs", path = "../../src", desc = "Source directory" },
      -- dynamic path
      { key = "gw", path = function() return vim.fn.getcwd() end, desc = "Current working directory" },
    },
  }
})
```

## 🚀 Usage

### Basic Navigation


| Key                | Action                                    |
| -----              | --------                                  |
| `p`                | Toggle preview window                     |
| `q`, `gq`, `<c-q>` | Close netrw and return to previous buffer |
| `h`                | Go to parent directory                    |
| `l`                | Enter directory or open file              |
| `~`                | Go to home directory                      |


### 🧠 Smart Enter Feature

The `l` key (or your configured `enter_dir` mapping) provides intelligent behavior:

- **On directories**: Normal navigation (same as `<CR>`)
- **On files**: Opens file AND preserves proper alternate buffer context
  - If opening the same file you came from → alternate = previous alternate buffer
  - If opening a different file → alternate = file you came from

This creates intuitive buffer navigation when jumping between files via netrw.

### File Operations


| Key | Action |
|-----|--------|
| `Y` | Yank absolute path to clipboard |
| `.` | Insert relative path in command line |


### Preview Features

- **File Preview**: Shows file contents with syntax highlighting
- **Directory Preview**: Shows directory contents with folders listed first
- **Binary Files**: Displays file information for binary files
- **Large Files**: Automatically truncates large files (>500 lines) for performance
- **Layout Options**: Choose between vertical (left/right) or horizontal (above/below) preview splits
- **Customizable Sizing**: Configure preview window width for vertical splits or height for horizontal splits

## 📝 Commands


| Command                      | Description                                                 |
| ---------                    | -------------                                               |
| `:NetrwReveal`               | Reveal current file in netrw                                |
| `:NetrwRevealToggle`         | Toggle NetrwReveal                                          |
| `:NetrwRevealLex`            | Reveal current file in netrw (Lexplore)                     |
| `:NetrwRevealLexToggle`      | Toggle NetrwRevealLex                                       |
| `:NetrwLastBuffer`           | Smart alternate buffer with netrw reveal                    |
| `:NetrwPreviewToggle`        | Toggle preview window                                       |
| `:NetrwPreviewEnable`        | Enable preview                                              |
| `:NetrwPreviewDisable`       | Disable preview                                             |
| `:NetrwRevealFile [path]`    | Reveal specified file or open directory in netrw            |
| `:NetrwRevealFileLex [path]` | Reveal specified file or open directory in netrw (Lexplore) |


### Commands usage

`NetrwReveal`, `NetrwRevealLex` (and their toggle counterparts), and `NetrwLastBuffer` can be mapped globally as:

```lua
vim.keymap.set("n", ",,", "<cmd>NetrwReveal<cr>", { desc = "Open Netrw - Reveal current file" })
vim.keymap.set("n", "ga", "<cmd>NetrwLastBuffer<cr>", { desc = "Go to alternate buffer (with netrw reveal)" })
```

**NetrwRevealFile Examples:**

- Reveal current file (if no argument provided)

    `:NetrwRevealFile`

- Reveal specific file

    `:NetrwRevealFile /path/to/file.txt`

- Open directory in netrw

    `:NetrwRevealFile /path/to/directory`

    `:NetrwRevealFile ~/projects`

- Works with relative paths

    `:NetrwRevealFile ./lua/config/init.lua`

    `:NetrwRevealFile ../docs`

**NetrwLastBuffer Logic:**

- **From regular file to file**: uses `vim.cmd('edit #')` to ensure the alternate buffer appears in the buffer list if closed
- **From netrw**: uses `vim.cmd('buffer #')` to just switch to alternate buffer (usually a regular file)
- **From regular file to netrw**: uses `vim.cmd('edit #')` plus file reveal logic (as long as the file is in the same netrw directory)

The other commands (`NetrwPreviewToggle`, `NetrwPreviewEnable`, `NetrwPreviewDisable`) are designed to be used from within netrw buffers.


## 🔧 API

### Direct Function Access

```lua
local netrw_preview = require("netrw-preview")

-- Preview controls
netrw_preview.enable_preview()
netrw_preview.disable_preview({ delete_buffer = true })
netrw_preview.toggle_preview()

-- File/directory revelation
netrw_preview.reveal()                             -- Reveal current file
netrw_preview.reveal_lex()                         -- Reveal current file (Lexplore)
netrw_preview.reveal_file("/path/to/file.txt")     -- Reveal specific file
netrw_preview.reveal_file_lex("/path/to/file.txt") -- Reveal specific file (Lexplore)
netrw_preview.reveal_file("/path/to/directory")    -- Open specific directory
netrw_preview.reveal_file("~/projects")            -- Works with tilde expansion
netrw_preview.reveal_file("./src")                 -- Works with relative paths
```


## 🎯 Examples

### Auto-enable Preview

```lua
require("netrw-preview").setup({
  preview_enabled = true,
  preview_width = 50,
})

-- Create an autocmd to auto-reveal current file when opening netrw
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    if vim.fn.argc() == 0 then
      require("netrw-preview").reveal()
    end
  end,
})
```

### Custom Keybindings

```lua
require("netrw-preview").setup({
  mappings = {
    toggle_preview = { "p", "<Tab>" },
    close_netrw = { "q", "<Esc>" },
    yank_path = "yp",
  }
})
```

## 🔍 File Type Preview Support

### Supported Preview Types

- **Text files**: Full syntax highlighting
- **Code files**: Language-specific highlighting
- **Directories**: Sorted file listings (directories first)
- **Other files**: Non-text file size and type information
- **Large file handling**: Auto-truncation of files >500 lines for better performance

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a pull request. For major changes or additional features, it is recommended to open a new discussion first before embarking in writing a full PR.

Here's how you can contribute:

1. Fork the repository
2. Create a feature branch (git checkout -b feature/amazing-feature)
3. Commit your changes (git commit -m 'Add some amazing feature')
4. Push to the branch (git push origin feature/amazing-feature)
5. Open a Pull Request
6. Please make sure to follow the existing code style.

> [!NOTE]
> Netrw enhancements such as adding **file icons** or **displaying git status** are **not planned** to be added in this plugin.

## 📄 License

[MIT License](LICENSE) - see the LICENSE file for details.

## 🙏 Acknowledgments

- Built for Neovim's built-in netrw file explorer
- Inspired by various file manager related plugins in the Neovim ecosystem, such as `oil.nvim` and `vim-vinegar`
- Thanks to all contributors and users providing feedback

---

**Note**: This plugin enhances netrw without replacing it, maintaining compatibility with existing netrw workflows while adding powerful preview capabilities.

