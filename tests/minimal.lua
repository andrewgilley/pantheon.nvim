vim.opt.runtimepath:append(vim.fn.getcwd())

local pantheon = require("pantheon")
local actions = require("pantheon.actions")
local github = require("pantheon.github")

pantheon.setup()
assert(pantheon.config.contributors[1].username == "mitchellh")
assert(pantheon.config.contributors[2].username == "lukewagner")
assert(pantheon.config.contributors[3].username == "matklad")
assert(pantheon.config.contributors[4].username == "ThePrimeagen")
assert(pantheon.config.contributors[5].username == "tjdevries")
assert(pantheon.config.contributors[6].username == "ryanfleury")
assert(pantheon.config.contributors[7].username == "gingerBill")
assert(pantheon.config.contributors[8].username == "lattner")
assert(pantheon.config.contributors[9].username == "jonhoo")
assert(pantheon.config.contributors[10].username == "jorangreef")
assert(pantheon.config.contributors[11].username == "Jarred-Sumner")
assert(pantheon.config.contributors[12].username == "shadcn")
assert(pantheon.config.contributors[13].username == "karpathy")
assert(pantheon.config.contributors[14].username == "earthtojake")
assert(pantheon.config.contributors[15].username == "folke")
assert(pantheon.config.contributors[16].username == "rockorager")
assert(pantheon.config.contributors[17].username == "simonw")
assert(pantheon.config.contributors[18].username == "stevearc")

pantheon.setup({ contributors = { { name = "Ada", username = "ada" } } })
assert(#pantheon.config.contributors == 1)
assert(pantheon.config.contributors[1].username == "ada")
pantheon.setup()

local push = actions.describe({
  type = "PushEvent",
  repo = { name = "example/project" },
  payload = {
    size = 2,
    ref = "refs/heads/main",
    head = "abc123",
    commits = { { message = "First" }, { message = "Useful change\n\nMore detail" } },
  },
})
assert(push.text == "Pushed 2 commits to example/project · main")
assert(push.detail == "Useful change")
assert(push.url == "https://github.com/example/project/commit/abc123")

local comment = actions.describe({
  type = "IssueCommentEvent",
  repo = { name = "example/project" },
  payload = {
    issue = { number = 42, title = "Tighten the invariant", pull_request = {} },
    comment = { html_url = "https://github.com/example/project/pull/42#issuecomment-1" },
  },
})
assert(comment.text == "Commented on pull request #42 in example/project · Tighten the invariant")
assert(comment.url == "https://github.com/example/project/pull/42#issuecomment-1")

local original_events = github.events
github.events = function(username, _, callback)
  if username == "broken" then
    callback(nil, "unavailable", false)
    return
  end
  local created_at = username == "newer" and "2026-07-01T12:00:00Z" or "2026-06-30T12:00:00Z"
  callback({ { id = username, created_at = created_at } }, nil, true)
end

local combined_result
local combined_notice
github.events_many({
  { name = "Older", username = "older" },
  { name = "Broken", username = "broken" },
  { name = "Newer", username = "newer" },
}, { combined_limit = 1 }, function(events, err, _, notice)
  assert(not err)
  combined_result = events
  combined_notice = notice
end)
assert(#combined_result == 1)
assert(combined_result[1].id == "newer")
assert(combined_result[1]._pantheon_contributor.username == "newer")
assert(combined_notice == "Could not load 1 contributor feeds")
github.events = original_events

pantheon.open()
assert(vim.bo.filetype == "pantheon")
assert(vim.api.nvim_buf_get_lines(0, 1, 2, false)[1]:find("PEOPLE WORTH FOLLOWING", 1, true))
assert(vim.wo.cursorline)
assert(vim.wo.cursorlineopt == "line")
assert(vim.wo.winhighlight == "CursorLine:PmenuSel")
assert(vim.api.nvim_win_get_width(0) >= math.floor(vim.o.columns * 0.85))
local contributor_rows = vim.api.nvim_buf_get_lines(0, 4, 7, false)
assert(contributor_rows[1]:find("GITHUB", 1, true))
assert(contributor_rows[2]:find("All contributors", 1, true))
assert(contributor_rows[3]:find("@mitchellh", 1, true))
assert(vim.api.nvim_win_get_cursor(0)[1] == 6)
local preview_namespace = vim.api.nvim_get_namespaces().pantheon_preview
local preview_marks = vim.api.nvim_buf_get_extmarks(0, preview_namespace, 0, -1, { details = true })
assert(#preview_marks > 0)
local preview_text = {}
for _, mark in ipairs(preview_marks) do
  for _, chunk in ipairs(mark[4].virt_text or {}) do
    preview_text[#preview_text + 1] = chunk[1]
  end
end
assert(table.concat(preview_text, " "):find("ALL ACTIVITY", 1, true))
local directional_maps = {}
for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(0, "n")) do
  directional_maps[mapping.lhs] = mapping.desc
end
assert(directional_maps.i == "Move up in Pantheon")
assert(directional_maps.k == "Move down in Pantheon")
assert(directional_maps.j == "Move left in Pantheon")
assert(directional_maps.l == "Move right in Pantheon")
pantheon.close()

print("pantheon: tests passed")
