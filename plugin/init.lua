local Comp = require('completion')

vim.api.nvim_create_user_command('CompOn', function()
  Comp.start_completion()
end, {})

vim.api.nvim_create_user_command('CompOff', function()
  Comp.stop_completion()
end, {})
