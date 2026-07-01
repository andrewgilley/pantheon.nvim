local M = {}

local defaults = {
  width = 0.9,
  height = 0.88,
  border = "rounded",
  title = " Pantheon ",
  per_page = 30,
  combined_limit = 100,
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
    {
      name = "shadcn",
      username = "shadcn",
      description = "Creator of shadcn/ui and open-code interface tooling",
    },
    {
      name = "Andrej Karpathy",
      username = "karpathy",
      description = "AI researcher and creator of nanoGPT, llm.c, and micrograd",
    },
    {
      name = "Jake Fitzgerald",
      username = "earthtojake",
      description = "Creator of Text-to-CAD and source-controlled CAD tooling",
    },
    {
      name = "Folke Lemaitre",
      username = "folke",
      description = "Creator of lazy.nvim, LazyVim, and influential Neovim tooling",
    },
    {
      name = "Tim Culverhouse",
      username = "rockorager",
      description = "Creator of libvaxis and modern Zig terminal tooling",
    },
    {
      name = "Simon Willison",
      username = "simonw",
      description = "Creator of Datasette and prolific builder of practical LLM tooling",
    },
    {
      name = "Steven Arcangeli",
      username = "stevearc",
      description = "Creator of influential Neovim plugins and developer tooling",
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
