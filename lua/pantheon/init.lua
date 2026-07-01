local M = {}

local defaults = {
  width = nil,
  height = nil,
  border = "rounded",
  title = " Pantheon ",
}

M.config = vim.deepcopy(defaults)

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", defaults, opts or {})
end

function M.open()
  require("myfloat.window").open(M.config)
end

function M.close()
  require("myfloat.window").close()
end

function M.toggle()
  require("myfloat.window").toggle(M.config)
end

return M
