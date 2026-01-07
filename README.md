# httpie-runner.nvim

Neovim helper that lets you execute the `httpie` command written on the current line. It opens a fresh terminal split and streams the response so you can iterate on HTTP requests without leaving your editor.

## Requirements

- [httpie](https://httpie.io/cli) available in your `$PATH`
- Neovim 0.8+

## Installation

### Lazy.nvim

```lua
{
  "felipeRese/httpie-runner.nvim",
  config = function()
    require("httpie_runner").setup()
  end,
}
```

### packer.nvim

```lua
use({
  "felipeRese/httpie-runner.nvim",
  config = function()
    require("httpie_runner").setup()
  end,
})
```

## Usage

Write a regular `httpie` command (e.g. `http GET https://api.github.com`) on its own line and position the cursor on that line. Then run:

- `:HttpieRun`
- or map it, for example: `vim.keymap.set("n", "<leader>hr", "<cmd>HttpieRun<CR>", { desc = "Run httpie command" })`

The plugin opens a terminal split on the right (`botright vsplit` by default), executes the command, and leaves the terminal in insert mode so you can interact with the process if needed.

## Environment variables

Define uppercase shell assignments anywhere above the command line (e.g. `BASE_URL=https://api.example.com` or `export TOKEN=abc`). httpie-runner prepends those statements before executing the request so you can interpolate values such as `$BASE_URL` without leaving Neovim.

```http
BASE_URL=https://api.github.com
TOKEN="ghp_***"

http GET $BASE_URL/user "Authorization:Bearer $TOKEN"
```

If you prefer to keep placeholder wrappers in markdown files (e.g. to make it clear that values need to be filled in), put them at the top of the file using square or curly brackets such as:

```text
BASE_URL=[http://localhost:8080}
TOKEN={super-secret-token}
```

The surrounding brackets are stripped before running `httpie`, so the command receives plain `BASE_URL`/`TOKEN` values.

## Configuration

```lua
require("httpie_runner").setup({
  split_cmd = "botright vsplit",  -- window command used before opening the terminal
  start_insert = true,            -- jump into insert mode after spawning the terminal
  termopen_opts = {},             -- forwarded to vim.fn.termopen (env, cwd, etc.)
})
```

Setting `split_cmd = ""` (or `nil`) disables automatic window changes so the terminal reuses the current window.
