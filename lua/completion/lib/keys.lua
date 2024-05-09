local M = {}

-- Replaced Keys
M.RK = {
  backspace  = vim.api.nvim_replace_termcodes("<BS>", true, false, true),
  space      = vim.api.nvim_replace_termcodes("<Space>", true, false, true),
  escape     = vim.api.nvim_replace_termcodes("<Esc>", true, false, true),
  enter      = vim.api.nvim_replace_termcodes("<CR>", true, false, true), 
  tab        = vim.api.nvim_replace_termcodes("<Tab>", true, false, true),
  down       = vim.api.nvim_replace_termcodes("<Down>", true, false, true),
  up         = vim.api.nvim_replace_termcodes("<Up>", true, false, true),
  left       = vim.api.nvim_replace_termcodes("<Left>", true, false, true),
  right      = vim.api.nvim_replace_termcodes("<Right>", true, false, true),
  ctrl_o     = vim.api.nvim_replace_termcodes("<C-o>", true, false, true),
}


M.valid_keys = "qwertyuiopèìasdfghjklòàzxcvbnmQWERTYUIOPÈASDFGHJKLÒÀZXCVBNM_1234567890"

-- I didn't just use concatanation for the keys below 
-- becasue string.find() gives problems finding
-- the replaced keys
M.word_saving_keys = {
  ".", "?", "+", "-", "/", "'", "\"","(", "*", "[", "]", "{", "}", "!", "%", "=", 
 M.RK.space,
 M.RK.tab,
 M.RK.escape,
}


M.is_valid_key = function (key)
  return string.find(M.valid_keys, key, 1, true)
end


M.is_word_saving_key = function (key)
  for i, v in ipairs(M.word_saving_keys) do 
    if key == v then return true end 
  end 
  return false
end

return M 

