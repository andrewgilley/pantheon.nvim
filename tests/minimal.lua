vim.opt.runtimepath:append(vim.fn.getcwd())

local pantheon = require("pantheon")
local actions = require("pantheon.actions")
local browser = require("pantheon.browser")
local storage = require("pantheon.storage")

pantheon.setup({ persist_filters = false })
local expected_contributors = {
  "mitchellh", "lukewagner", "matklad", "ThePrimeagen", "ryanfleury",
  "gingerBill", "jonhoo", "Jarred-Sumner", "shadcn",
  "earthtojake", "folke", "rockorager", "simonw", "stevearc",
  "charliermarsh", "BurntSushi", "carllerche", "ggerganov",
  "dtolnay",
}
for index, username in ipairs(expected_contributors) do
  assert(pantheon.config.contributors[index].username == username)
end

pantheon.setup({
  persist_filters = false,
  activity_types = { "PushEvent" },
  user_activity_types = { mitchellh = { "ReleaseEvent" } },
})
assert(pantheon.config.activity_types[1] == "PushEvent")
assert(pantheon.config.user_activity_types.mitchellh[1] == "ReleaseEvent")
assert(#pantheon.config.contributors == #expected_contributors)
pantheon.setup({ persist_filters = false })

pantheon.setup({ persist_filters = false, contributors = { { name = "Ada", username = "ada" } } })
assert(#pantheon.config.contributors == 1)
assert(pantheon.config.contributors[1].username == "ada")
pantheon.setup({ persist_filters = false })

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

local filtered = actions.filter({
  { type = "PushEvent", id = "push" },
  { type = "WatchEvent", id = "watch" },
  { type = "ReleaseEvent", id = "release" },
}, { "PushEvent", "ReleaseEvent" })
assert(#filtered == 2)
assert(filtered[1].id == "push")
assert(filtered[2].id == "release")
assert(#actions.filter({ { type = "PushEvent" } }, {}) == 0)

local browser_command = browser.command({ browser_command = { "test-browser", "--new-window" } }, "https://example.com")
assert(vim.deep_equal(browser_command, { "test-browser", "--new-window", "https://example.com" }))

local state_file = vim.fn.tempname()
local saved, save_error = storage.save(state_file, {
  activity_types = { "ReleaseEvent" },
  user_activity_types = { mitchellh = { "PushEvent" } },
})
assert(saved, save_error)
saved, save_error = storage.save(state_file, {
  activity_types = { "ReleaseEvent" },
  user_activity_types = { mitchellh = { "PushEvent" } },
})
assert(saved, save_error)
pantheon.setup({ persist_filters = true, state_file = state_file })
assert(pantheon.config.activity_types[1] == "ReleaseEvent")
assert(pantheon.config.user_activity_types.mitchellh[1] == "PushEvent")
vim.fn.delete(state_file)
pantheon.setup({ persist_filters = false })

pantheon.open()
assert(vim.bo.filetype == "pantheon")
assert(vim.api.nvim_buf_get_lines(0, 1, 2, false)[1]:find("COMMUNITY FIGURES", 1, true))
assert(not vim.wo.cursorline)
assert(vim.wo.cursorlineopt == "line")
assert(vim.wo.winhighlight == "CursorLine:PmenuSel")
assert(vim.api.nvim_win_get_width(0) >= math.floor(vim.o.columns * 0.85))
assert(vim.api.nvim_win_get_config(0).row == 1)
local contributor_rows = vim.api.nvim_buf_get_lines(0, 4, 5 + #expected_contributors, false)
assert(contributor_rows[1]:find("GITHUB", 1, true))
local rendered_contributors = table.concat(contributor_rows, "\n")
for _, username in ipairs(expected_contributors) do
  assert(rendered_contributors:find("@" .. username, 1, true))
end
local first_username = contributor_rows[2]:match("@([%w%-]+)")
assert(first_username)
assert(pantheon.config.contributors[1].username == "mitchellh")
assert(vim.api.nvim_win_get_cursor(0)[1] == 6)
local selection_namespace = vim.api.nvim_get_namespaces().pantheon_selection
local selection_marks = vim.api.nvim_buf_get_extmarks(0, selection_namespace, 0, -1, { details = true })
assert(#selection_marks == 1)
assert(selection_marks[1][4].end_col == #contributor_rows[2])
local preview_namespace = vim.api.nvim_get_namespaces().pantheon_preview
local preview_marks = vim.api.nvim_buf_get_extmarks(0, preview_namespace, 0, -1, { details = true })
assert(#preview_marks > 0)
local preview_text = {}
for _, mark in ipairs(preview_marks) do
  for _, chunk in ipairs(mark[4].virt_text or {}) do
    preview_text[#preview_text + 1] = chunk[1]
  end
end
assert(table.concat(preview_text, " "):find("@" .. first_username, 1, true))
local directional_maps = {}
for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(0, "n")) do
  directional_maps[mapping.lhs] = mapping.desc
end
assert(directional_maps.i == "Move up in Pantheon")
assert(directional_maps.k == "Move down in Pantheon")
assert(directional_maps.j == "Move left in Pantheon")
assert(directional_maps.l == "Move right in Pantheon")

vim.api.nvim_feedkeys("F", "x", false)
assert(vim.wait(500, function()
  return require("pantheon.window").state.view == "filters"
end))
assert(vim.wo.cursorline)
assert(vim.api.nvim_get_current_line():find("[x]", 1, true))
vim.api.nvim_feedkeys(" ", "x", false)
assert(vim.wait(500, function()
  return pantheon.config.activity_types ~= nil
end))
assert(#pantheon.config.activity_types == #actions.event_types - 1)
assert(not vim.tbl_contains(pantheon.config.activity_types, "PushEvent"))
vim.api.nvim_feedkeys("j", "x", false)
assert(vim.wait(500, function()
  return require("pantheon.window").state.view == "contributors"
end))
pantheon.close()

print("pantheon: tests passed")
