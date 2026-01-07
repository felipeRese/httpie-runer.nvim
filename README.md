# httpie-runner.nvim

Neovim helper that lets you execute the `httpie` command written on the current line. It opens a fresh split (right side by default) and streams the response into a regular buffer so you can read, search, and yank the payload without leaving your editor.

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

The plugin opens a scratch buffer on the right (`botright vsplit` by default), executes the command, and streams the response into it. Because the buffer behaves like any other Neovim window you can move around, search, and copy text immediately. Set `output = "terminal"` if you prefer to run inside a traditional terminal buffer.

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
  split_cmd = "botright vsplit",  -- window command used before opening the output buffer
  output = "buffer",              -- "buffer" (default) or "terminal"
  start_insert = true,            -- only relevant when output = "terminal"
  termopen_opts = {},             -- forwarded to the underlying job/terminal (env, cwd, etc.)
  httpie_opts = "--pretty=format",-- options automatically inserted after the http/https command
})
```

Setting `split_cmd = ""` (or `nil`) disables automatic window changes so the output reuses the current window.

## Formatting & highlighting

httpie disables its pretty printer whenever `stdout` isn't a TTY. Because httpie-runner streams everything into a scratch buffer, it injects `--pretty=format` right after the `http`/`https` command by default so the payload stays nicely formatted without ANSI escape sequences. Override or disable it via the `httpie_opts` option if you prefer the raw output or want to provide a different set of flags (for example `--pretty=all --style=solarized`).

The scratch buffer uses the `httpie-runner` filetype and ships with a small syntax definition so status lines, headers, stderr, and JSON snippets get highlighted automatically.
