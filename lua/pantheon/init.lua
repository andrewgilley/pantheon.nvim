local M = {}

local defaults = {
  width = 0.9,
  height = 0.88,
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
    {
      name = "Alex Kladov",
      username = "matklad",
      description = "Rust Analyzer co-creator and TigerBeetle engineer",
    },
    {
      name = "ThePrimeagen",
      username = "ThePrimeagen",
      description = "Vim, developer tooling, and performance-focused programming",
    },
    {
      name = "TJ DeVries",
      username = "tjdevries",
      description = "Neovim core contributor and original creator of Telescope.nvim",
    },
    {
      name = "Ryan Fleury",
      username = "ryanfleury",
      description = "Systems programming, debuggers, and data-oriented tools",
    },
    {
      name = "Ginger Bill",
      username = "gingerBill",
      description = "Creator of the Odin programming language",
    },
    {
      name = "Chris Lattner",
      username = "lattner",
      description = "Creator of LLVM, Clang, Swift, and Mojo",
    },
    {
      name = "Jon Gjengset",
      username = "jonhoo",
      description = "Rust educator and distributed systems engineer",
    },
    {
      name = "Joran Dirk Greef",
      username = "jorangreef",
      description = "Creator, founder, and CEO of TigerBeetle",
    },
    {
      name = "Jarred Sumner",
      username = "Jarred-Sumner",
      description = "Creator of the Bun JavaScript runtime and toolkit",
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
