if vim.g.loaded_httpie_runner then
  return
end
vim.g.loaded_httpie_runner = true

vim.api.nvim_create_user_command("HttpieRun", function()
  require("httpie_runner").run_current_line()
end, {
  desc = "Run the httpie command defined on the current line",
})

