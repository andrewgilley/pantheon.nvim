# pantheon.nvim

Pantheon is a small Neovim browser for the recent public GitHub activity of
people whose work is worth following.

## Requirements

- Neovim 0.10+
- `curl`

## Setup

```lua
require("pantheon").setup({
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
