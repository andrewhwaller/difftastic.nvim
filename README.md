# difftastic.nvim

A Neovim plugin that integrates [difftastic](https://difftastic.wilfred.me.uk/) to show syntax-aware diffs inline in your code.

## Features

- **Inline diff overlay** - Shows syntax-highlighted changes directly in your buffer
- **Smart change detection**:
  - Pure additions (new lines) - Displayed as virtual text
  - Modifications (changed lines) - Only highlights the changed portions in green
  - Deletions (removed lines) - Shows as red italic virtual text
- **Non-destructive** - Uses virtual text and extmarks, never modifies your buffer
- **Auto-refresh** - Diffs update automatically when you save
- **Preserves syntax highlighting** - Your editor's syntax highlighting stays intact for unchanged code
- **Split view** - Traditional side-by-side diff view available

## Requirements

- Neovim 0.10+
- [difftastic](https://difftastic.wilfred.me.uk/) installed and available in your PATH

## Installation

### Install difftastic

```bash
# macOS/Linux
brew install difftastic

# Or via cargo
cargo install difftastic
```

### Install the plugin

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "andrewhwaller/difftastic.nvim",
  config = function()
    require("difftastic-nvim").setup({
      target_branch = "main",  -- Branch to diff against (default: "main")
    })
  end,
  keys = {
    { "<leader>dt", "<cmd>DifftasticToggle<cr>", desc = "Toggle Difftastic Overlay" },
    { "<leader>ds", "<cmd>DifftasticSplit<cr>", desc = "Difftastic Split View" },
  },
}
```

## Usage

### Commands

- `:DifftasticToggle` - Toggle the inline diff overlay on/off
- `:DifftasticSplit` - Open a split window with the full diff

### How it works

The plugin compares your current file against:
- If on `target_branch`: Shows uncommitted changes (HEAD vs working tree)
- If on feature branch: Shows changes vs `target_branch` (e.g., `main...HEAD`)

Changes are displayed inline:
- **Green virtual text** = Added lines
- **Green highlights** = Modified tokens within a line
- **Red virtual text** = Deleted lines

You can continue editing while the overlay is active. Saving the file automatically refreshes the diff.

## Configuration

```lua
require("difftastic-nvim").setup({
  target_branch = "main",  -- The branch to compare against (default: "main")
})
```

## How is this different from other diff plugins?

- **Syntax-aware**: Uses difftastic's structural diff algorithm instead of line-based diffs
- **Non-destructive**: Never modifies your buffer - all changes shown via virtual text
- **Inline**: Shows changes directly in your code, not in a separate window
- **Smart highlighting**: Only highlights the actual changed tokens, preserving your syntax highlighting

## License

MIT
