local M = {}

local actions = require("pantheon.actions")
local github = require("pantheon.github")

local ns = vim.api.nvim_create_namespace("pantheon")

M.state = {
  buf = nil,
  win = nil,
  view = "contributors",
  contributor = nil,
  events = nil,
  line_targets = {},
  request_id = 0,
  opts = {},
}

local function is_valid_win(win)
  return win and vim.api.nvim_win_is_valid(win)
end

local function is_valid_buf(buf)
  return buf and vim.api.nvim_buf_is_valid(buf)
end

local function dimension(value, total, fallback, minimum)
  local result
  if type(value) == "number" and value > 0 and value <= 1 then
    result = math.floor(total * value)
  else
    result = tonumber(value) or math.floor(total * fallback)
  end
  return math.min(math.max(minimum, math.floor(result)), math.max(1, total - 4))
end

local function make_win_config(opts)
  local width = dimension(opts.width, vim.o.columns, 0.72, 54)
  local height = dimension(opts.height, vim.o.lines, 0.72, 16)

  return {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = opts.border or "rounded",
    title = opts.title or " Pantheon ",
    title_pos = "center",
  }
end

local function make_buf()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "pantheon"
  return buf
end

local function set_lines(lines)
  if not is_valid_buf(M.state.buf) then
    return
  end
  vim.bo[M.state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(M.state.buf, 0, -1, false, lines)
  vim.bo[M.state.buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(M.state.buf, ns, 0, -1)
end

local function highlight(line, start_col, end_col, group)
  vim.api.nvim_buf_add_highlight(M.state.buf, ns, group, line - 1, start_col, end_col)
end

local function trim_to_width(text, width)
  if vim.fn.strdisplaywidth(text) <= width then
    return text
  end
  return vim.fn.strcharpart(text, 0, math.max(1, width - 1)) .. "…"
end

local function relative_time(timestamp)
  if not timestamp then
    return "unknown time"
  end
  local year, month, day, hour, minute, second = timestamp:match(
    "^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)Z$"
  )
  if not year then
    return timestamp
  end

  local then_time = os.time({
    year = tonumber(year),
    month = tonumber(month),
    day = tonumber(day),
    hour = tonumber(hour),
    min = tonumber(minute),
    sec = tonumber(second),
    isdst = false,
  })
  local offset = os.difftime(os.time(), os.time(os.date("!*t")))
  local seconds = math.max(0, os.difftime(os.time(), then_time - offset))

  if seconds < 60 then
    return "just now"
  elseif seconds < 3600 then
    local count = math.floor(seconds / 60)
    return count .. (count == 1 and " minute ago" or " minutes ago")
  elseif seconds < 86400 then
    local count = math.floor(seconds / 3600)
    return count .. (count == 1 and " hour ago" or " hours ago")
  elseif seconds < 604800 then
    local count = math.floor(seconds / 86400)
    return count .. (count == 1 and " day ago" or " days ago")
  end
  return os.date("%b %d, %Y", then_time - offset)
end

local function footer(lines, text)
  lines[#lines + 1] = ""
  lines[#lines + 1] = "  " .. text
end

local function render_contributors()
  M.state.view = "contributors"
  M.state.contributor = nil
  M.state.events = nil
  M.state.line_targets = {}

  local lines = {
    "",
    "  PEOPLE WORTH FOLLOWING",
    "  Recent public work from thoughtful builders",
    "",
  }

  for index, contributor in ipairs(M.state.opts.contributors or {}) do
    local line = #lines + 1
    lines[line] = ("  %d  %s"):format(index, contributor.name or contributor.username)
    lines[#lines + 1] = ("     @%s · %s"):format(
      contributor.username,
      contributor.description or "GitHub contributor"
    )
    lines[#lines + 1] = ""
    M.state.line_targets[line] = contributor
    M.state.line_targets[line + 1] = contributor
  end

  if #(M.state.opts.contributors or {}) == 0 then
    lines[#lines + 1] = "  No contributors configured."
  end
  footer(lines, "↵ view activity   o open profile   q close")
  set_lines(lines)

  highlight(2, 2, -1, "Title")
  highlight(3, 2, -1, "Comment")
  for line, _ in pairs(M.state.line_targets) do
    if lines[line]:match("^  %d") then
      highlight(line, 2, -1, "Function")
    else
      highlight(line, 5, -1, "Comment")
    end
  end
  highlight(#lines, 2, -1, "Comment")

  if M.state.line_targets[5] and is_valid_win(M.state.win) then
    vim.api.nvim_win_set_cursor(M.state.win, { 5, 0 })
  end
end

local function render_loading(contributor)
  local lines = {
    "",
    "  " .. (contributor.name or contributor.username),
    "  @" .. contributor.username,
    "",
    "  Loading recent GitHub activity…",
  }
  footer(lines, "b back   q close")
  set_lines(lines)
  highlight(2, 2, -1, "Title")
  highlight(3, 2, -1, "Comment")
  highlight(5, 2, -1, "DiagnosticInfo")
end

local function render_error(message)
  local contributor = M.state.contributor
  local lines = {
    "",
    "  " .. (contributor.name or contributor.username),
    "  @" .. contributor.username,
    "",
    "  Could not load activity",
    "  " .. message,
  }
  footer(lines, "r retry   b back   o open profile   q close")
  set_lines(lines)
  highlight(2, 2, -1, "Title")
  highlight(3, 2, -1, "Comment")
  highlight(5, 2, -1, "DiagnosticError")
  highlight(6, 2, -1, "Comment")
end

local function render_activity(events, cached)
  local contributor = M.state.contributor
  M.state.events = events
  M.state.line_targets = {}
  local width = vim.api.nvim_win_get_width(M.state.win)
  local lines = {
    "",
    "  " .. (contributor.name or contributor.username),
    ("  @%s · %d recent public events%s"):format(
      contributor.username,
      #events,
      cached and " · cached" or ""
    ),
    "",
  }

  for _, event in ipairs(events) do
    local item = actions.describe(event)
    local event_line = #lines + 1
    lines[event_line] = trim_to_width(("  %s  %s"):format(item.icon, item.text), width - 2)
    lines[#lines + 1] = "     " .. relative_time(event.created_at)
    if item.detail then
      lines[#lines + 1] = trim_to_width("     “" .. item.detail .. "”", width - 2)
    end
    lines[#lines + 1] = ""
    M.state.line_targets[event_line] = item.url
    M.state.line_targets[event_line + 1] = item.url
    if item.detail then
      M.state.line_targets[event_line + 2] = item.url
    end
  end

  if #events == 0 then
    lines[#lines + 1] = "  No recent public activity was returned."
  end
  footer(lines, "o open event   r refresh   b back   q close")
  set_lines(lines)

  highlight(2, 2, -1, "Title")
  highlight(3, 2, -1, "Comment")
  for line, _ in pairs(M.state.line_targets) do
    if lines[line]:match("^  .  ") then
      highlight(line, 2, 3, "Special")
      highlight(line, 5, -1, "Function")
    else
      highlight(line, 5, -1, "Comment")
    end
  end
  highlight(#lines, 2, -1, "Comment")
  if #events > 0 then
    vim.api.nvim_win_set_cursor(M.state.win, { 5, 0 })
  end
end

local function load_activity(contributor, force)
  M.state.view = "activity"
  M.state.contributor = contributor
  M.state.request_id = M.state.request_id + 1
  local request_id = M.state.request_id
  render_loading(contributor)

  local request_opts = vim.tbl_extend("force", M.state.opts, { force = force or false })
  github.events(contributor.username, request_opts, function(events, err, cached)
    if request_id ~= M.state.request_id or not is_valid_win(M.state.win) then
      return
    end
    if err then
      render_error(err)
    else
      render_activity(events, cached)
    end
  end)
end

local function target_on_cursor()
  if not is_valid_win(M.state.win) then
    return nil
  end
  local line = vim.api.nvim_win_get_cursor(M.state.win)[1]
  if M.state.line_targets[line] then
    return M.state.line_targets[line]
  end
  for distance = 1, 2 do
    if M.state.line_targets[line - distance] then
      return M.state.line_targets[line - distance]
    elseif M.state.line_targets[line + distance] then
      return M.state.line_targets[line + distance]
    end
  end
end

local function open_url(url)
  local ok, err = vim.ui.open(url)
  if not ok and err then
    vim.notify("Pantheon: " .. tostring(err), vim.log.levels.ERROR)
  end
end

local function select_current()
  local target = target_on_cursor()
  if M.state.view == "contributors" and type(target) == "table" then
    load_activity(target, false)
  elseif M.state.view == "activity" and type(target) == "string" then
    open_url(target)
  end
end

local function open_current()
  local target = target_on_cursor()
  if M.state.view == "contributors" and type(target) == "table" then
    open_url("https://github.com/" .. target.username)
  elseif M.state.view == "activity" then
    if type(target) == "string" then
      open_url(target)
    elseif M.state.contributor then
      open_url("https://github.com/" .. M.state.contributor.username)
    end
  end
end

local function map_keys(buf)
  local map = function(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { buffer = buf, nowait = true, silent = true, desc = desc })
  end
  map("q", M.close, "Close Pantheon")
  map("<Esc>", M.close, "Close Pantheon")
  map("<CR>", select_current, "Select Pantheon item")
  map("o", open_current, "Open Pantheon item in browser")
  map("b", function()
    if M.state.view == "activity" then
      M.state.request_id = M.state.request_id + 1
      render_contributors()
    end
  end, "Return to Pantheon contributors")
  map("r", function()
    if M.state.view == "activity" and M.state.contributor then
      github.clear(M.state.contributor.username)
      load_activity(M.state.contributor, true)
    end
  end, "Refresh Pantheon activity")
end

function M.close()
  M.state.request_id = M.state.request_id + 1
  if is_valid_win(M.state.win) then
    vim.api.nvim_win_close(M.state.win, true)
  end
  M.state.buf = nil
  M.state.win = nil
  M.state.contributor = nil
  M.state.events = nil
  M.state.line_targets = {}
end

function M.open(opts)
  M.state.opts = opts or {}
  if is_valid_win(M.state.win) then
    vim.api.nvim_set_current_win(M.state.win)
    return
  end

  local buf = make_buf()
  local win = vim.api.nvim_open_win(buf, true, make_win_config(M.state.opts))
  M.state.buf = buf
  M.state.win = win

  vim.wo[win].wrap = false
  vim.wo[win].cursorline = true
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].winfixbuf = true

  map_keys(buf)
  render_contributors()

  vim.api.nvim_create_autocmd("VimResized", {
    buffer = buf,
    callback = function()
      if is_valid_win(M.state.win) then
        vim.api.nvim_win_set_config(M.state.win, make_win_config(M.state.opts))
      end
    end,
  })
end

function M.toggle(opts)
  if is_valid_win(M.state.win) then
    M.close()
  else
    M.open(opts)
  end
end

return M
