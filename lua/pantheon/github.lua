local M = {}

local cache = {}

local function decode_response(stdout)
  local body, status = stdout:match("^(.*)\n(%d%d%d)%s*$")
  if not status then
    return nil, "GitHub returned an invalid response"
  end

  if tonumber(status) ~= 200 then
    local ok, payload = pcall(vim.json.decode, body)
    local message = ok and payload and payload.message or ("HTTP " .. status)
    return nil, "GitHub: " .. message
  end

  local ok, events = pcall(vim.json.decode, body)
  if not ok or type(events) ~= "table" then
    return nil, "GitHub returned malformed JSON"
  end

  return events
end

function M.events(username, opts, callback)
  opts = opts or {}
  local ttl = opts.cache_ttl or 300
  local cached = cache[username]

  if not opts.force and cached and os.time() - cached.fetched_at < ttl then
    vim.schedule(function()
      callback(cached.events, nil, true)
    end)
    return
  end

  if vim.fn.executable("curl") ~= 1 then
    vim.schedule(function()
      callback(nil, "Pantheon requires curl to load GitHub activity")
    end)
    return
  end

  local url = ("https://api.github.com/users/%s/events/public?per_page=%d"):format(
    username,
    opts.per_page or 30
  )
  local command = {
    "curl",
    "-sS",
    "-L",
    "--max-time",
    tostring(opts.request_timeout or 15),
    "-H",
    "Accept: application/vnd.github+json",
    "-H",
    "User-Agent: pantheon.nvim",
    "-w",
    "\n%{http_code}",
  }

  local token = opts.token or vim.env.GITHUB_TOKEN
  local stdin
  if token and token ~= "" then
    vim.list_extend(command, { "-H", "@-" })
    stdin = "Authorization: Bearer " .. token .. "\n"
  end
  table.insert(command, url)

  vim.system(command, { text = true, stdin = stdin }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        local message = vim.trim(result.stderr or "")
        callback(nil, message ~= "" and message or "Unable to reach GitHub")
        return
      end

      local events, err = decode_response(result.stdout or "")
      if not events then
        callback(nil, err)
        return
      end

      cache[username] = { events = events, fetched_at = os.time() }
      callback(events, nil, false)
    end)
  end)
end

function M.clear(username)
  cache[username] = nil
end

return M
