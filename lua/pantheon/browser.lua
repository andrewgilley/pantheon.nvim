local M = {}

local function first_executable(candidates)
  for _, candidate in ipairs(candidates) do
    if candidate and candidate ~= "" and vim.fn.executable(candidate) == 1 then
      return candidate
    end
  end
end

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

  local system = vim.uv.os_uname().sysname
  if system == "Windows_NT" then
    local program_files_x86 = vim.env["PROGRAMFILES(X86)"]
    local browser = first_executable({
      vim.env.LOCALAPPDATA and (vim.env.LOCALAPPDATA .. "\\Google\\Chrome\\Application\\chrome.exe"),
      vim.env.PROGRAMFILES and (vim.env.PROGRAMFILES .. "\\Google\\Chrome\\Application\\chrome.exe"),
      program_files_x86 and (program_files_x86 .. "\\Microsoft\\Edge\\Application\\msedge.exe"),
      vim.env.PROGRAMFILES and (vim.env.PROGRAMFILES .. "\\Microsoft\\Edge\\Application\\msedge.exe"),
    })
    if browser then
      return { browser, "--no-first-run", "--no-default-browser-check", "--app=" .. url }
    end

    local firefox = first_executable({
      vim.env.PROGRAMFILES and (vim.env.PROGRAMFILES .. "\\Mozilla Firefox\\firefox.exe"),
      program_files_x86 and (program_files_x86 .. "\\Mozilla Firefox\\firefox.exe"),
    })
    if firefox then
      return { firefox, "-new-window", url }
    end
  elseif system == "Darwin" and vim.fn.executable("open") == 1 then
    return { "open", "-n", url }
  else
    local browser = first_executable({ "google-chrome", "chromium", "chromium-browser" })
    if browser then
      return { browser, "--no-first-run", "--no-default-browser-check", "--app=" .. url }
    end
    local firefox = first_executable({ "firefox" })
    if firefox then
      return { firefox, "--new-window", url }
    end
  end
end

function M.open(url, config)
  local command = M.command(config, url)
  if not command then
    return vim.ui.open(url)
  end

  local ok, process = pcall(vim.system, command, { detach = true })
  if not ok then
    return nil, process
  end
  return process
end

return M
