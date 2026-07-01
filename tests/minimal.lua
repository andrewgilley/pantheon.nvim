vim.opt.runtimepath:append(vim.fn.getcwd())

local pantheon = require("pantheon")
local actions = require("pantheon.actions")

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
assert(vim.wo.cursorline)
assert(vim.wo.cursorlineopt == "line")
assert(vim.wo.winhighlight == "CursorLine:PmenuSel")
assert(vim.api.nvim_win_get_width(0) >= math.floor(vim.o.columns * 0.85))
local contributor_rows = vim.api.nvim_buf_get_lines(0, 4, 7, false)
assert(contributor_rows[1]:find("GITHUB", 1, true))
assert(contributor_rows[2]:find("@mitchellh", 1, true))
assert(contributor_rows[3]:find("@lukewagner", 1, true))
assert(vim.api.nvim_win_get_cursor(0)[1] == 6)
pantheon.close()

print("pantheon: tests passed")
