vim.api.nvim_create_user_command("XpresentXStart", function()
  require("xPRESENTx").start_xPRESENTx()
end, {})
