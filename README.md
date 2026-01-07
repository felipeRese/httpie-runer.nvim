# httpie-runner.nvim

Neovim helper that lets you execute the `httpie` command written on the current line. It opens a fresh terminal split and streams the response so you can iterate on HTTP requests without leaving your editor.

## Requirements

- [httpie](https://httpie.io/cli) available in your `$PATH`
- Neovim 0.8+

## Installation

### Lazy.nvim

```lua
{
  "felipecrs/httpie-runner.nvim",
  config = function()
    require("httpie_runner").setup()
  end,
}
```

### packer.nvim

```lua
use({
  "felipecrs/httpie-runner.nvim",
  config = function()
    require("httpie_runner").setup()
  end,
})
```

## Usage

Write a regular `httpie` command (e.g. `http GET https://api.github.com`) on its own line and position the cursor on that line. Then run:

- `:HttpieRun`
- or map it, for example: `vim.keymap.set("n", "<leader>hr", "<cmd>HttpieRun<CR>", { desc = "Run httpie command" })`

The plugin opens a terminal split (`botright 15split` by default), executes the command, and leaves the terminal in insert mode so you can interact with the process if needed.

## Configuration

```lua
require("httpie_runner").setup({
  split_cmd = "botright 15split", -- window command used before opening the terminal
  start_insert = true,            -- jump into insert mode after spawning the terminal
  termopen_opts = {},             -- forwarded to vim.fn.termopen (env, cwd, etc.)
})
```

Setting `split_cmd = ""` (or `nil`) disables automatic window changes so the terminal reuses the current window.

