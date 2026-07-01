local M = {}

local defaults = {
  width = 0.72,
  height = 0.72,
  border = "rounded",
  title = " Pantheon ",
  per_page = 30,
  cache_ttl = 300,
  request_timeout = 15,
  token = nil,
  contributors = {
    {
      name = "Mitchell Hashimoto",
      username = "mitchellh",
      description = "Creator of Ghostty, HashiCorp, Vagrant, Terraform, and Nomad",
    },
    {
      name = "Luke Wagner",
      username = "lukewagner",
      description = "WebAssembly and JavaScript engine engineer",
    },
  },
}

M.config = vim.deepcopy(defaults)

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
  if opts and opts.contributors then
    M.config.contributors = vim.deepcopy(opts.contributors)
  end
end

function M.open()
  require("pantheon.window").open(M.config)
end

function M.close()
  require("pantheon.window").close()
end

function M.toggle()
  require("pantheon.window").toggle(M.config)
end

return M
