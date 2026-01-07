local M = {}

local defaults = {
  split_cmd = "botright 15split",
  start_insert = true,
  termopen_opts = {},
}

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function extend_opts(opts)
  return vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
end

local function ensure_config()
  if not M.config then
    M.config = vim.deepcopy(defaults)
  end
end

function M.setup(opts)
  M.config = extend_opts(opts)
end

local function open_output_window()
  ensure_config()
  local split_cmd = M.config.split_cmd
  if split_cmd and #split_cmd > 0 then
    vim.cmd(split_cmd)
  end

  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(win, buf)

  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "httpie-runner"
  return buf
end

local function notify(msg, level)
  vim.notify("[httpie-runner] " .. msg, level or vim.log.levels.INFO)
end

function M.run_current_line()
  ensure_config()

  local line = vim.api.nvim_get_current_line()
  local cmd = trim(line or "")
  if cmd == "" then
    notify("Current line is empty. Nothing to run.", vim.log.levels.WARN)
    return
  end

  open_output_window()

  local opts = vim.tbl_deep_extend(
    "force",
    M.config.termopen_opts or {},
    {
      on_exit = function(_, code)
        if code ~= 0 then
          vim.schedule(function()
            notify(("Command exited with code %d"):format(code), vim.log.levels.ERROR)
          end)
        end
      end,
    }
  )

  vim.fn.termopen({ "sh", "-c", cmd }, opts)

  if M.config.start_insert then
    vim.cmd("startinsert")
  end
end

return M

