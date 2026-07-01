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

function M.events_many(contributors, opts, callback)
  if #contributors == 0 then
    vim.schedule(function()
      callback({}, nil, true)
    end)
    return
  end

  local pending = #contributors
  local merged = {}
  local errors = {}
  local all_cached = true

  for _, contributor in ipairs(contributors) do
    M.events(contributor.username, opts, function(events, err, cached)
      all_cached = all_cached and cached == true
      if err then
        errors[#errors + 1] = contributor.username .. ": " .. err
      else
        for _, event in ipairs(events) do
          local item = vim.tbl_extend("force", {}, event)
          item._pantheon_contributor = contributor
          merged[#merged + 1] = item
        end
      end

      pending = pending - 1
      if pending ~= 0 then
        return
      end

      table.sort(merged, function(left, right)
        return (left.created_at or "") > (right.created_at or "")
      end)

      local limit = opts.combined_limit or 100
      if #merged > limit then
        merged = vim.list_slice(merged, 1, limit)
      end

      if #merged == 0 and #errors > 0 then
        callback(nil, table.concat(errors, "; "), false)
      else
        local notice = #errors > 0 and ("Could not load " .. #errors .. " contributor feeds") or nil
        callback(merged, nil, all_cached, notice)
      end
    end)
  end
end

function M.clear(username)
  cache[username] = nil
end

return M
