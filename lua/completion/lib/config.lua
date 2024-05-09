local Trie = require("completion.lib.trie")
local M = {}


-- selection and win background highlights 
vim.api.nvim_set_hl(0, 'ironmanBG', {bg ="#c97e22"})
vim.api.nvim_set_hl(0, 'ironmanSHL', {bg ="#9c0000", fg="#ffffff", bold=true})

vim.api.nvim_set_hl(0, 'pgBG', {bg ="#93a5ac"})
vim.api.nvim_set_hl(0, 'pgSHL', {bg ="#fdc1b1", fg ="#ffffff", bold=true})

vim.api.nvim_set_hl(0, 'spidermanBG', {bg ="#124c70"})
vim.api.nvim_set_hl(0, 'spidermanSHL', {bg ="#5d81a7", fg ="#ffffff", bold=true})

vim.api.nvim_set_hl(0, 'phBG', {bg ="#282D30"})
vim.api.nvim_set_hl(0, 'phSHL', {bg ="#FB9400", fg="#ffffff", bold=true})

M.bg_hl = "phBG"  
M.s_hl = "phSHL"  


M.get_win_opts = function(all_matches)
  height = #all_matches
  table.sort(all_matches, function(a, b) return #a < #b end) 
  width = #all_matches[#all_matches] + 1 -- c_win width is length of longest match 
  return {
    relative = "cursor",
    width = width,
    height = height,
    focusable = false,
    row = 1, -- cursor coords + 1
    col = 1, 
    style  = "minimal",
    border = "single"
  } 
end 

M.handle_win = function(event, c_winnr, c_bufnr)
  if event == "InsertLeave" and c_winnr then 
    vim.api.nvim_win_close(c_winnr, true) 
    return nil  
  end 

  local all_matches = vim.api.nvim_buf_get_lines(c_bufnr, 0, -1, true) 
  if all_matches[1] ~= "" then 
    local win_opts = M.get_win_opts(all_matches)
    if c_winnr then 
      vim.api.nvim_win_set_config(c_winnr, win_opts)
    else 
      c_winnr = vim.api.nvim_open_win(c_bufnr, false, win_opts)
    end 

    vim.api.nvim_win_set_option(c_winnr, 'winhighlight','Normal:' .. M.bg_hl) 
    return c_winnr
  end 
   
  if c_winnr then 
    vim.api.nvim_win_close(c_winnr, true) 
    return nil 
  end 
end


M.highlight_match = function(c_bufnr, match_row)
  vim.api.nvim_buf_add_highlight(c_bufnr, 0, M.s_hl, match_row, 0, -1) 
end 

M.generate_completion_state = function()
  return {
    completion_on = false,
    match_row = 0,
    curs_row = 0,
    curs_col = 0,
    word_at_curs = "",
    trie_root = Trie:new_node(),
    typed = false,
  }
end 

return M





