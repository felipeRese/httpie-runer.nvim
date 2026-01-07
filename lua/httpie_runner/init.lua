local M = {}

local defaults = {
  split_cmd = "botright vsplit",
  output = "buffer",
  start_insert = true,
  termopen_opts = {},
  httpie_opts = "--pretty=format",
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

local function merge_term_opts(overrides)
  ensure_config()

  local opts = vim.tbl_deep_extend(
    "force",
    vim.deepcopy(M.config.termopen_opts or {}),
    overrides or {}
  )

  local httpie_opts = M.config.httpie_opts
  if httpie_opts == false or httpie_opts == "" or type(httpie_opts) ~= "string" then
    httpie_opts = nil
  end

  if httpie_opts then
    local env = vim.tbl_deep_extend("force", {}, opts.env or {})
    if env.HTTPIE_OPTIONS == nil then
      env.HTTPIE_OPTIONS = httpie_opts
    end
    opts.env = env
  end

  return opts
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

local function replace_buffer_lines(buf, start, finish, lines)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, start, finish, false, lines)
  vim.bo[buf].modifiable = false
end

local function append_to_buffer(buf, lines)
  if not lines or #lines == 0 then
    return
  end

  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local prev_lines = vim.api.nvim_buf_line_count(buf)

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, -1, -1, false, lines)
  vim.bo[buf].modifiable = false

  local new_line_count = vim.api.nvim_buf_line_count(buf)
  local wins = vim.fn.win_findbuf(buf)
  for _, win in ipairs(wins) do
    local cursor = vim.api.nvim_win_get_cursor(win)
    if cursor[1] >= prev_lines then
      vim.api.nvim_win_set_cursor(win, { new_line_count, 0 })
    end
  end
end

local function sanitize_job_chunk(data, prefix)
  if not data or vim.tbl_isempty(data) then
    return {}
  end

  local sanitized = {}
  for idx, value in ipairs(data) do
    if value ~= "" then
      if prefix and prefix ~= "" then
        table.insert(sanitized, prefix .. value)
      else
        table.insert(sanitized, value)
      end
    elseif idx ~= #data then
      table.insert(sanitized, "")
    end
  end

  return sanitized
end

local function notify(msg, level)
  vim.notify("[httpie-runner] " .. msg, level or vim.log.levels.INFO)
end

local function run_in_terminal(final_cmd)
  open_output_window()

  local opts = merge_term_opts({
    on_exit = function(_, code)
      if code ~= 0 then
        vim.schedule(function()
          notify(("Command exited with code %d"):format(code), vim.log.levels.ERROR)
        end)
      end
    end,
  })

  vim.fn.termopen({ "sh", "-c", final_cmd }, opts)

  if M.config.start_insert then
    vim.cmd("startinsert")
  else
    vim.cmd("stopinsert")
  end
end

local function format_command_lines(final_cmd)
  local lines = vim.split(final_cmd, "\n", { trimempty = true })
  if vim.tbl_isempty(lines) then
    return { "$ " .. final_cmd }
  end

  local formatted = {}
  for _, line in ipairs(lines) do
    if line ~= "" then
      table.insert(formatted, "$ " .. line)
    end
  end

  return formatted
end

local function run_in_buffer(final_cmd)
  local buf = open_output_window()
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].modifiable = false

  local header = format_command_lines(final_cmd)
  table.insert(header, "")
  replace_buffer_lines(buf, 0, -1, header)

  local job_id

  local job_opts = merge_term_opts({
    stdout_buffered = false,
    stderr_buffered = false,
  })

  if job_opts.stdin == nil then
    -- Close STDIN so commands don't block waiting for input (httpie waits otherwise).
    job_opts.stdin = "null"
  end

  job_opts.on_stdout = function(_, data)
    local lines = sanitize_job_chunk(data)
    if #lines == 0 then
      return
    end

    vim.schedule(function()
      append_to_buffer(buf, lines)
    end)
  end

  job_opts.on_stderr = function(_, data)
    local lines = sanitize_job_chunk(data, "[stderr] ")
    if #lines == 0 then
      return
    end

    vim.schedule(function()
      append_to_buffer(buf, lines)
    end)
  end

  job_opts.on_exit = function(_, code)
    vim.schedule(function()
      append_to_buffer(buf, { "", ("[exit %d]"):format(code) })
      if code ~= 0 then
        notify(("Command exited with code %d"):format(code), vim.log.levels.ERROR)
      end
    end)
  end

  job_id = vim.fn.jobstart({ "sh", "-c", final_cmd }, job_opts)
  if job_id <= 0 then
    notify("Failed to start command.", vim.log.levels.ERROR)
    return
  end

  vim.api.nvim_buf_attach(buf, false, {
    on_detach = function()
      if job_id > 0 then
        pcall(vim.fn.jobstop, job_id)
      end
    end,
  })
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

  local mode = M.config.output or "buffer"
  if mode == "terminal" then
    run_in_terminal(final_cmd)
  else
    run_in_buffer(final_cmd)
  end
end

return M
