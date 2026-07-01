local M = {}

local actions = require("pantheon.actions")
local github = require("pantheon.github")

local ns = vim.api.nvim_create_namespace("pantheon")
local preview_ns = vim.api.nvim_create_namespace("pantheon_preview")

M.state = {
  buf = nil,
  win = nil,
  view = "contributors",
  contributor = nil,
  events = nil,
  line_targets = {},
  request_id = 0,
  preview_request_id = 0,
  preview_key = nil,
  preview_items = nil,
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
  local width = dimension(opts.width, vim.o.columns, 0.9, 54)
  local height = dimension(opts.height, vim.o.lines, 0.88, 16)

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
  vim.api.nvim_buf_clear_namespace(M.state.buf, preview_ns, 0, -1)
  M.state.preview_items = nil
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

local function pad_cell(text, width)
  local value = trim_to_width(text, width)
  return value .. string.rep(" ", math.max(0, width - vim.fn.strdisplaywidth(value)))
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

local function preview_left_width(window_width)
  return math.max(30, math.min(math.max(40, math.floor(window_width * 0.46)), window_width - 22))
end

local function render_preview_panel(items)
  if M.state.view ~= "contributors" or not is_valid_buf(M.state.buf) or not is_valid_win(M.state.win) then
    return
  end

  vim.api.nvim_buf_clear_namespace(M.state.buf, preview_ns, 0, -1)
  M.state.preview_items = items
  local window_width = vim.api.nvim_win_get_width(M.state.win)
  local left_width = preview_left_width(window_width)
  local right_width = math.max(16, window_width - left_width - 3)
  local line_count = vim.api.nvim_buf_line_count(M.state.buf)

  for line = 1, line_count do
    local item = items[line]
    local text = item and trim_to_width(item[1], right_width - 1) or ""
    local group = item and item[2] or "NormalFloat"
    vim.api.nvim_buf_set_extmark(M.state.buf, preview_ns, line - 1, 0, {
      virt_text = {
        { "│", "WinSeparator" },
        { " " .. text, group },
      },
      virt_text_win_col = left_width,
      hl_mode = "combine",
    })
  end
end

local function preview_items(contributor, events, err, cached)
  local items = {
    [2] = { "PREVIEW", "Title" },
    [4] = { contributor.name or contributor.username, "Function" },
    [5] = { contributor.combined and "Combined feed" or ("@" .. contributor.username), "Identifier" },
    [7] = { contributor.description or "GitHub contributor", "Comment" },
  }

  if contributor.combined then
    items[9] = { "ALL ACTIVITY", "Special" }
    items[10] = { "Merges every contributor into one", "NormalFloat" }
    items[11] = { "newest-first timeline.", "NormalFloat" }
    items[13] = { "Press l or <Enter> to open.", "Comment" }
    return items
  end

  if err then
    items[9] = { "PREVIEW UNAVAILABLE", "DiagnosticError" }
    items[10] = { err, "Comment" }
    return items
  end

  if not events then
    items[9] = { "Loading recent activity…", "DiagnosticInfo" }
    return items
  end

  items[9] = { "RECENT ACTIVITY" .. (cached and " · CACHED" or ""), "Special" }
  if #events == 0 then
    items[10] = { "No recent public events.", "Comment" }
    return items
  end

  local line = 10
  for index = 1, math.min(3, #events) do
    local event = events[index]
    local item = actions.describe(event)
    items[line] = { item.icon .. "  " .. item.text, "NormalFloat" }
    items[line + 1] = { relative_time(event.created_at), "Comment" }
    line = line + 3
  end
  return items
end

local function queue_preview(contributor)
  if not contributor or M.state.view ~= "contributors" then
    return
  end

  local key = contributor.combined and "__combined" or contributor.username
  if M.state.preview_key == key then
    return
  end
  M.state.preview_key = key
  M.state.preview_request_id = M.state.preview_request_id + 1
  local request_id = M.state.preview_request_id

  render_preview_panel(preview_items(contributor))
  if contributor.combined then
    return
  end

  vim.defer_fn(function()
    if request_id ~= M.state.preview_request_id or M.state.view ~= "contributors" then
      return
    end
    github.events(contributor.username, M.state.opts, function(events, err, cached)
      if request_id ~= M.state.preview_request_id or M.state.view ~= "contributors" then
        return
      end
      render_preview_panel(preview_items(contributor, events, err, cached))
    end)
  end, 150)
end

local function render_contributors()
  M.state.view = "contributors"
  M.state.contributor = nil
  M.state.events = nil
  M.state.line_targets = {}
  M.state.preview_key = nil
  M.state.preview_request_id = M.state.preview_request_id + 1

  local lines = {
    -- "",
    "  COMMUNITY FIGURES",
    "  Public GitHub activity",
    "",
  }

  local contributors = M.state.opts.contributors or {}
  local choices = {}
  if #contributors > 0 then
    choices[1] = {
      name = "All contributors",
      combined = true,
      contributors = contributors,
      description = "One timeline merged from every contributor below",
    }
    vim.list_extend(choices, contributors)
  end

  local index_width = #tostring(math.max(#contributors, 1))
  local left_width = preview_left_width(vim.api.nvim_win_get_width(M.state.win))
  local name_width = 4
  local username_width = 6
  for _, contributor in ipairs(choices) do
    name_width = math.max(name_width, #(contributor.name or contributor.username))
    username_width = math.max(username_width, #(contributor.combined and "all" or ("@" .. contributor.username)))
  end
  username_width = math.min(username_width, 14)
  name_width = math.min(name_width, math.max(10, left_width - index_width - username_width - 8))

  lines[#lines + 1] = ("  %" .. index_width .. "s  %s  %s"):format(
    "#", pad_cell("CONTRIBUTOR", name_width), pad_cell("GITHUB", username_width)
  )

  for index, contributor in ipairs(choices) do
    local line = #lines + 1
    local index_label = contributor.combined and "*" or tostring(index - 1)
    local handle = contributor.combined and "all" or ("@" .. contributor.username)
    local prefix = ("  %" .. index_width .. "s  %s  %s"):format(
      index_label,
      pad_cell(contributor.name or contributor.username, name_width),
      pad_cell(handle, username_width)
    )
    lines[line] = prefix
    M.state.line_targets[line] = contributor
  end

  if #contributors == 0 then
    lines[#lines + 1] = "  No contributors configured."
  end
  footer(lines, "i/k move   l open   q close")
  set_lines(lines)

  highlight(2, 2, -1, "Title")
  highlight(3, 2, -1, "Comment")
  highlight(5, 2, -1, "Comment")
  for line, _ in pairs(M.state.line_targets) do
    local username_start = lines[line]:find("@", 1, true)
    highlight(line, 2, username_start and (username_start - 2) or -1, "Function")
    if username_start then
      highlight(line, username_start - 1, username_start + username_width, "Identifier")
    end
  end
  highlight(#lines, 2, -1, "Comment")

  if M.state.line_targets[6] and is_valid_win(M.state.win) then
    vim.api.nvim_win_set_cursor(M.state.win, { 6, 0 })
    queue_preview(M.state.line_targets[6])
  end
end

local function render_loading(contributor)
  local subtitle = contributor.combined and "Merging every configured public feed" or ("@" .. contributor.username)
  local lines = {
    "",
    "  " .. (contributor.name or contributor.username),
    "  " .. subtitle,
    "",
    "  Loading recent GitHub activity…",
  }
  footer(lines, "j/b back   q close")
  set_lines(lines)
  highlight(2, 2, -1, "Title")
  highlight(3, 2, -1, "Comment")
  highlight(5, 2, -1, "DiagnosticInfo")
end

local function render_error(message)
  local contributor = M.state.contributor
  local subtitle = contributor.combined and "Combined activity" or ("@" .. contributor.username)
  local lines = {
    "",
    "  " .. (contributor.name or contributor.username),
    "  " .. subtitle,
    "",
    "  Could not load activity",
    "  " .. message,
  }
  footer(lines, "r retry   j/b back   o open profile   q close")
  set_lines(lines)
  highlight(2, 2, -1, "Title")
  highlight(3, 2, -1, "Comment")
  highlight(5, 2, -1, "DiagnosticError")
  highlight(6, 2, -1, "Comment")
end

local function render_activity(events, cached, notice)
  local contributor = M.state.contributor
  M.state.events = events
  M.state.line_targets = {}
  local width = vim.api.nvim_win_get_width(M.state.win)
  local subtitle = contributor.combined and "all configured contributors" or ("@" .. contributor.username)
  local lines = {
    "",
    "  " .. (contributor.name or contributor.username),
    ("  %s · %d recent public events%s"):format(
      subtitle,
      #events,
      cached and " · cached" or ""
    ),
  }
  if notice then
    lines[#lines + 1] = "  " .. notice
  end
  lines[#lines + 1] = ""

  local first_event_line
  for _, event in ipairs(events) do
    local item = actions.describe(event)
    local event_line = #lines + 1
    first_event_line = first_event_line or event_line
    local actor = event._pantheon_contributor
    local actor_prefix = actor and ((actor.name or actor.username) .. " · ") or ""
    lines[event_line] = trim_to_width(("  %s  %s%s"):format(item.icon, actor_prefix, item.text), width - 2)
    lines[#lines + 1] = "     " .. relative_time(event.created_at)
    if item.detail then
      lines[#lines + 1] = trim_to_width("     “" .. item.detail .. "”", width - 2)
    end
    M.state.line_targets[event_line] = item.url
    M.state.line_targets[event_line + 1] = item.url
    if item.detail then
      M.state.line_targets[event_line + 2] = item.url
    end
  end

  if #events == 0 then
    lines[#lines + 1] = "  No recent public activity was returned."
  end
  footer(lines, "i/k move   l/↵ open event   r refresh   j/b back   q close")
  set_lines(lines)

  highlight(2, 2, -1, "Title")
  highlight(3, 2, -1, "Comment")
  if notice then
    highlight(4, 2, -1, "DiagnosticWarn")
  end
  for line, _ in pairs(M.state.line_targets) do
    if lines[line]:match("^  .  ") then
      highlight(line, 2, 3, "Special")
      highlight(line, 5, -1, "Function")
    else
      highlight(line, 5, -1, "Comment")
    end
  end
  highlight(#lines, 2, -1, "Comment")
  if first_event_line then
    vim.api.nvim_win_set_cursor(M.state.win, { first_event_line, 0 })
  end
end

local function load_activity(contributor, force)
  M.state.view = "activity"
  M.state.contributor = contributor
  M.state.request_id = M.state.request_id + 1
  local request_id = M.state.request_id
  render_loading(contributor)

  local request_opts = vim.tbl_extend("force", M.state.opts, { force = force or false })
  local callback = function(events, err, cached, notice)
    if request_id ~= M.state.request_id or not is_valid_win(M.state.win) then
      return
    end
    if err then
      render_error(err)
    else
      render_activity(events, cached, notice)
    end
  end

  if contributor.combined then
    github.events_many(contributor.contributors, request_opts, callback)
  else
    github.events(contributor.username, request_opts, callback)
  end
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
    open_url(target.combined and "https://github.com" or ("https://github.com/" .. target.username))
  elseif M.state.view == "activity" then
    if type(target) == "string" then
      open_url(target)
    elseif M.state.contributor then
      open_url("https://github.com/" .. M.state.contributor.username)
    end
  end
end

local function move_cursor(direction)
  if M.state.view ~= "contributors" then
    vim.cmd.normal({ direction > 0 and "j" or "k", bang = true })
    return
  end

  local selectable = {}
  for line, target in pairs(M.state.line_targets) do
    if type(target) == "table" then
      selectable[#selectable + 1] = line
    end
  end
  table.sort(selectable)
  if #selectable == 0 then
    return
  end

  local current = vim.api.nvim_win_get_cursor(M.state.win)[1]
  local selected = direction > 0 and selectable[1] or selectable[#selectable]
  for index, line in ipairs(selectable) do
    if line == current then
      local next_index = ((index - 1 + direction) % #selectable) + 1
      selected = selectable[next_index]
      break
    elseif direction > 0 and line > current then
      selected = line
      break
    elseif direction < 0 and line < current then
      selected = line
    end
  end
  vim.api.nvim_win_set_cursor(M.state.win, { selected, 0 })
  queue_preview(M.state.line_targets[selected])
end

local function go_back()
  if M.state.view == "activity" then
    M.state.request_id = M.state.request_id + 1
    render_contributors()
  end
end

local function map_keys(buf)
  local map = function(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { buffer = buf, nowait = true, silent = true, desc = desc })
  end
  map("q", M.close, "Close Pantheon")
  map("<Esc>", M.close, "Close Pantheon")
  map("<CR>", select_current, "Select Pantheon item")
  map("l", select_current, "Move right in Pantheon")
  map("o", open_current, "Open Pantheon item in browser")
  map("i", function()
    move_cursor(-1)
  end, "Move up in Pantheon")
  map("k", function()
    move_cursor(1)
  end, "Move down in Pantheon")
  map("j", go_back, "Move left in Pantheon")
  map("<Down>", function()
    move_cursor(1)
  end, "Select next Pantheon contributor")
  map("<Up>", function()
    move_cursor(-1)
  end, "Select previous Pantheon contributor")
  map("b", go_back, "Return to Pantheon contributors")
  map("r", function()
    if M.state.view == "activity" and M.state.contributor then
      if M.state.contributor.combined then
        for _, contributor in ipairs(M.state.contributor.contributors) do
          github.clear(contributor.username)
        end
      else
        github.clear(M.state.contributor.username)
      end
      load_activity(M.state.contributor, true)
    end
  end, "Refresh Pantheon activity")
end

function M.close()
  M.state.request_id = M.state.request_id + 1
  M.state.preview_request_id = M.state.preview_request_id + 1
  if is_valid_win(M.state.win) then
    vim.api.nvim_win_close(M.state.win, true)
  end
  M.state.buf = nil
  M.state.win = nil
  M.state.contributor = nil
  M.state.events = nil
  M.state.line_targets = {}
  M.state.preview_key = nil
  M.state.preview_items = nil
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
  vim.wo[win].cursorlineopt = "line"
  vim.wo[win].winhighlight = "CursorLine:PmenuSel"
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
        if M.state.view == "contributors" and M.state.preview_items then
          render_preview_panel(M.state.preview_items)
        end
      end
    end,
  })

  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = buf,
    callback = function()
      if M.state.view ~= "contributors" or not is_valid_win(M.state.win) then
        return
      end
      local line = vim.api.nvim_win_get_cursor(M.state.win)[1]
      local contributor = M.state.line_targets[line]
      if type(contributor) == "table" then
        queue_preview(contributor)
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
