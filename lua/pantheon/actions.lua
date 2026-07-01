local M = {}

local window = require("pantheon.window")

local function telescope_builtin()
  local ok, builtin = pcall(require, "telescope.builtin")

  if not ok then
    vim.notify("telescope.nvim is not installed", vim.log.levels.WARN)
    return nil
  end

  return builtin
end

function M.find_files()
  local builtin = telescope_builtin()
  if not builtin then
    return
  end

  window.close()

  builtin.find_files({
    prompt_title = "Find files",
    layout_strategy = "dropdown",
    layout_config = {
      width = 0.8,
      height = 0.6,
    },
  })
end

function M.live_grep()
  local builtin = telescope_builtin()
  if not builtin then
    return
  end

  window.close()

  builtin.live_grep({
    prompt_title = "Live grep",
    layout_strategy = "dropdown",
    layout_config = {
      width = 0.8,
      height = 0.6,
    },
  })
end

return M
