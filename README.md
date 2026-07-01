# pantheon.nvim

Pantheon is a small Neovim browser for the recent public GitHub activity of
people whose work is worth following.

## Requirements

- Neovim 0.10+
- `curl`

## Setup

```lua
require("pantheon").setup({
  width = 0.9,
  height = 0.88,
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
})
```

Run `:PantheonOpen`, `:PantheonClose`, or `:PantheonToggle`.

Inside Pantheon:

- `<CR>` selects a contributor or opens an activity item.
- `o` opens the selected profile or activity item in your browser.
- `r` bypasses the five-minute cache and refreshes activity.
- `b` returns to the contributor list.
- `q` or `<Esc>` closes the window.

Pantheon uses GitHub's public events API. It works without authentication and
uses `GITHUB_TOKEN` automatically when that environment variable is present.
You may instead pass `token` to `setup`, though environment variables are safer
than storing credentials in your Neovim configuration.

GitHub public events are not real-time and can be delayed. Only public activity
is shown.
