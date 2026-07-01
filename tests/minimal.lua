vim.opt.runtimepath:append(vim.fn.getcwd())

local pantheon = require("pantheon")
local actions = require("pantheon.actions")

pantheon.setup()
assert(pantheon.config.contributors[1].username == "mitchellh")
assert(pantheon.config.contributors[2].username == "lukewagner")

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

pantheon.open()
assert(vim.bo.filetype == "pantheon")
assert(vim.api.nvim_buf_get_lines(0, 1, 2, false)[1]:find("PEOPLE WORTH FOLLOWING", 1, true))
pantheon.close()

print("pantheon: tests passed")
