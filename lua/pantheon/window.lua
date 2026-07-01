local M = {}

M.state = {
  buf = nil,
  win = nil,
}

local function is_valid_win(win)
  return win and vim.api.nvim_win_is_valid(win)
end

local function is_valid_buf(buf)
  return buf and vim.api.nvim_buf_is_valid(buf)
end

local function make_buf()
  local buf = vim.api.nvim_create_buf(false, true)

  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = true
  vim.bo[buf].filetype = "myfloat"

  return buf
end

local function make_win_config(opts)
  opts = opts or {}

  local width = opts.width or math.floor(vim.o.columns * 0.5)
  local height = opts.height or math.floor(vim.o.lines * 0.4)

  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  return {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = opts.border or "rounded",
    title = opts.title or " Pantheon ",
    title_pos = "center",
  }
end

function M.render(lines)
  if not is_valid_buf(M.state.buf) then
    return
  end

  vim.bo[M.state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(M.state.buf, 0, -1, false, lines)
  vim.bo[M.state.buf].modifiable = false
end

function M.close()
  if is_valid_win(M.state.win) then
    vim.api.nvim_win_close(M.state.win, true)
  end

  M.state.win = nil
  M.state.buf = nil
end

function M.open(opts)
  opts = opts or {}

  if is_valid_win(M.state.win) then
    vim.api.nvim_set_current_win(M.state.win)
    return
  end

  local buf = make_buf()
  local win = vim.api.nvim_open_win(buf, true, make_win_config(opts))

  M.state.buf = buf
  M.state.win = win

  vim.wo[win].wrap = false
  vim.wo[win].cursorline = true
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"

  M.render({
    "Pantheon.nvim",
    "",
    "f  Find files with Telescope",
    "g  Live grep with Telescope",
    "r  Refresh",
    "q  Close",
  })

  vim.keymap.set("n", "q", M.close, {
    buffer = buf,
    nowait = true,
    silent = true,
    desc = "Close Pantheon",
  })

  vim.keymap.set("n", "<Esc>", M.close, {
    buffer = buf,
    nowait = true,
    silent = true,
    desc = "Close Pantheon",
  })

  vim.keymap.set("n", "r", function()
    M.render({
      "Pantheon.nvim",
      "",
      "Refreshed at " .. os.date("%H:%M:%S"),
      "",
      "f  Find files with Telescope",
      "g  Live grep with Telescope",
      "q  Close",
    })
  end, {
  buffer = buf,
  nowait = true,
  silent = true,
  desc = "Refresh Pantheon",
})

vim.api.nvim_create_autocmd("VimResized", {
  buffer = buf,
  callback = function()
    if is_valid_win(M.state.win) then
      vim.api.nvim_win_set_config(M.state.win, make_win_config(opts))
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
