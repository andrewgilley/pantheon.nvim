local M = {}

function M.command(config, url)
  local configured = config.browser_command
  if type(configured) == "function" then
    return configured(url)
  elseif type(configured) == "table" and #configured > 0 then
    local command = {}
    local has_url = false
    for _, argument in ipairs(configured) do
      local replaced, count = argument:gsub("{url}", function()
        return url
      end)
      command[#command + 1] = replaced
      has_url = has_url or count > 0
    end
    if not has_url then
      command[#command + 1] = url
    end
    return command
  end
end

function M.open(url, config)
  local command = M.command(config, url)
  if not command then
    -- Delegate to the operating system's standard browser handler.
    return vim.ui.open(url)
  end

  local ok, process = pcall(vim.system, command, { detach = true })
  if not ok then
    return nil, process
  end
  return process
end

return M
