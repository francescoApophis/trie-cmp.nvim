local M = {}

Comp = require("completion.lib.completion")
Conf = require("completion.lib.config")
Keys = require("completion.lib.keys")
Trie = require("completion.lib.trie")

local comp_group_name = 'Trie_Completion'
local c_bufnr = vim.api.nvim_create_buf(false, true)
local state = Conf.generate_completion_state()

-- vim.on_key removes the callback if it's nil.
-- I know this is some ugly ass code but I haven't found a better ways 
-- to do that.
---@param key string Pressed key received from vim.on_key
main = function(key)
  if not state.completion_on then
    main = nil 
    return 
  end 

  Comp.completion(key, c_bufnr, state)
end


---@param comp_group_name string Name for autogroup
M.activate_autocmds = function(comp_group_name)
  local comp_group = vim.api.nvim_create_augroup(comp_group_name, {clear = true})
  vim.api.nvim_create_autocmd('BufRead', {
    pattern = "*.*", 
    callback = function()
      Comp.save_words_from_opened_buf(state.trie_root)
    end,
    group= comp_group 
  })
  
  vim.api.nvim_create_autocmd({'CursorMovedI', 'InsertEnter', 'InsertLeave'}, {
    callback = function(event)
      c_winnr = Conf.handle_win(event.event, c_winnr, c_bufnr)
    end,
    group= comp_group 
  })
end 


---@return nil 
M.start_completion = function()
  if state.completion_on then 
    print('Completion already on')
    return 
  else
    print('Completion on')
  end 
  
  if vim.api.nvim_buf_get_option(0, 'buftype') ~= "" then 
    error("Completion off, current buffer is not a 'file' buffer")
  end 

  state.completion_on = true     
  Comp.save_words_from_opened_buf(state.trie_root)  -- 'BufRead' will have already been fired once user-command is called 
  M.activate_autocmds(comp_group_name)
  vim.on_key(main)
end 


---@return nil 
M.stop_completion = function()
  if not state.completion_on then 
    print('Completion already off')
    return 
  else 
    print('Completion off')
  end  
  state = Conf.generate_completion_state()
  vim.api.nvim_del_augroup_by_name(comp_group_name)
  vim.keymap.set('i', '<Enter>', Keys.RK.enter, {noremap = true, silent = true})
end 

return M
