local M = {}

local defaults = {
  split_cmd = "botright 15split",
  start_insert = true,
  termopen_opts = {},
}

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function unwrap_placeholder_value(value)
  if not value or #value < 2 then
    return value
  end

  local first = value:sub(1, 1)
  local last = value:sub(-1)
  local closing = {
    ["["] = { "]", "}" },
    ["{"] = { "}", "]" },
    ["<"] = { ">" },
  }

  local expected = closing[first]
  if not expected then
    return value
  end

  for _, candidate in ipairs(expected) do
    if last == candidate then
      return trim(value:sub(2, #value - 1))
    end
  end

  return value
end

local function parse_env_assignment(line)
  if not line then
    return nil
  end

  local trimmed = trim(line)
  if trimmed == "" or trimmed:match("^#") then
    return nil
  end

  local assignment = trimmed
  local export_prefix = assignment:match("^export%s+(.+)$")
  if export_prefix then
    assignment = export_prefix
  end

  local name, value = assignment:match("^([A-Z_][A-Z0-9_]*)%s*=%s*(.*)$")
  if not name then
    return nil
  end

  value = trim(value)
  value = unwrap_placeholder_value(value)

  return name .. "=" .. value
end

local function collect_env_assignments(bufnr, upto_line)
  local env_lines = {}

  if upto_line <= 1 then
    return env_lines
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, upto_line - 1, false)
  for _, line in ipairs(lines) do
    local assignment = parse_env_assignment(line)
    if assignment then
      table.insert(env_lines, assignment)
    end
  end

  return env_lines
end

local function command_with_env(cmd, bufnr, line_nr)
  local env_lines = collect_env_assignments(bufnr, line_nr)
  if #env_lines == 0 then
    return cmd
  end

  return table.concat(env_lines, "\n") .. "\n" .. cmd
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

  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = vim.api.nvim_get_current_line()
  local cmd = trim(line or "")
  if cmd == "" then
    notify("Current line is empty. Nothing to run.", vim.log.levels.WARN)
    return
  end

  local final_cmd = command_with_env(cmd, bufnr, cursor[1])

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

  vim.fn.termopen({ "sh", "-c", final_cmd }, opts)

  if M.config.start_insert then
    vim.cmd("startinsert")
  end
end

return M
