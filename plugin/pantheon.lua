if vim.g.loaded_myfloat then
  return
end

vim.g.loaded_myfloat = true

vim.api.nvim_create_user_command("PantheonOpen", function()
  require("myfloat").open()
end, {})

vim.api.nvim_create_user_command("PantheonClose", function()
  require("myfloat").close()
end, {})

vim.api.nvim_create_user_command("PantheonToggle", function()
  require("myfloat").toggle()
end, {})
