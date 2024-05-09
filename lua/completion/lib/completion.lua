local M = {}

---@param c_bufnr number 
---@param trie_root trie_node
---@param word_at_curs string 
M.search_and_show_matches = function (c_bufnr, trie_root, word_at_curs)
  vim.api.nvim_buf_set_lines(c_bufnr, 0, -1, true, {} ) -- DELETE ALL PREVIOUS MATCHES

  local matches = Trie.get_all_matches(trie_root, word_at_curs)
  if matches then 
    vim.api.nvim_buf_set_lines(c_bufnr, 0, -1, true, matches) 
  end 
end  

---@param c_bufnr number 
---@return boolean first_line_in_c_bufnr
M.matches_exist_in_buf = function(c_bufnr) 
  return vim.api.nvim_buf_get_lines(c_bufnr, 0, 1, true)[1] ~= "" 
end 


---@param trie_root trie_node
M.save_words_from_opened_buf = function(trie_root)
  new_buf_lines = vim.fn.readfile(vim.fn.bufname())
  if #new_buf_lines < 1 then return end  

  for i, line in ipairs(new_buf_lines) do 
    for word in string.gmatch(line, "%w+%_-%w+") do 
      if #word > 1 then  Trie.add_word(trie_root, word) end 
    end 
  end 
end 


-- Enter key still has default mapping, so the text after cursor  
-- will go to a newline after selecting a match. I don't wanna remap anything so 
-- I copy the curr line, delete the newline,
-- put the copied line back and set the cursor after inserted match  
---@param curs_row number 
---@param word_start_col number 
---@param selected_match_len number 
M.undo_newline = function(curs_row, word_start_col, selected_match_len)
  local curr_buf_line = vim.api.nvim_get_current_line()
  vim.schedule(function()
    vim.api.nvim_buf_set_lines(0, curs_row , curs_row + 1, true, {})
    vim.api.nvim_buf_set_lines(0, curs_row - 1 , curs_row, true, {curr_buf_line}) 
    vim.api.nvim_win_set_cursor(0, {curs_row, word_start_col + selected_match_len})
  end) 
end 
 

---@param key string 
---@match_row number 
---@param c_bufnr number 
---@return number match_row 
M.get_new_match_row = function(key, match_row, c_bufnr)
  local c_bufnr_len = vim.api.nvim_buf_line_count(c_bufnr)
  if key == Keys.RK.down then 
    return (match_row + 1 >= c_bufnr_len and 0) or match_row + 1
  end 
  return (match_row - 1 < 0 and c_bufnr_len - 1) or match_row - 1
end 


---@param curs_col number 
---@param word_at_curs_len number 
---@return number match_row 
M.get_word_start_col = function(curs_col, word_at_curs_len)
  if curs_col - word_at_curs_len < 0 then 
    return 0
  -- read cmnt for 'i' key pressed in Normal mode in M.completion()
  elseif (curs_col - word_at_curs_len) == curs_col then  
    return curs_col - #M.get_word_at_curs(curs_col) 
  end 
  return curs_col - word_at_curs_len 
end 
 
---@param curs_col number 
---@return string word_at_curs
M.get_word_at_curs = function(curs_col) 
  local curr_line_until_curs = string.sub(vim.api.nvim_get_current_line(), 1, curs_col)
  return string.match(curr_line_until_curs, "%w+%_-%w+$") or ""
end 

---@param key string 
---@param trie_root trie_node
---@param word_at_curs string 
---@return string word_at_curs
M.handle_valid_keys = function(key, c_bufnr, trie_root, word_at_curs, curs_col)
  word_at_curs = word_at_curs .. key
  M.search_and_show_matches(c_bufnr, trie_root, word_at_curs)
  return word_at_curs
end 


---@param c_bufnr number 
---@param trie_root trie_node
---@param word_at_curs string 
---@param curs_col number 
---@return string word_at_curs 
---@return number curs_col 
M.handle_deletion = function(c_bufnr, trie_root, word_at_curs, curs_col)
  word_at_curs = string.sub(word_at_curs, 1, #word_at_curs - 1)
  curs_col = (curs_col - 1 < 0 and 0) or curs_col - 1
  M.search_and_show_matches(c_bufnr, trie_root, word_at_curs)
  return word_at_curs, curs_col
end 


---@param c_bufnr number 
---@param trie_root trie_node
---@param word_at_curs string 
---@param typed boolean If the user has typed any new letters
M.handle_word_saving_key = function(c_bufnr, trie_root, word_at_curs, typed)
  if not typed then 
    return 
  end 
  if #word_at_curs > 1 then 
    Trie.add_word(trie_root, word_at_curs)
  end 
  vim.api.nvim_buf_set_lines(c_bufnr, 0, -1, true, {}) 
end 



---@param c_bufnr number
---@param trie_root trie_node
---@param word_at_curs string 
---@param curs_row number 
---@param curs_col number 
---@param match_row number 
---@return number | nil New curs_col, which is the end of the inserted word
M.handle_match_insertion = function(c_bufnr, trie_root, word_at_curs, curs_row, curs_col, match_row)
  if not M.matches_exist_in_buf(c_bufnr) then 
    Trie.add_word(trie_root, word_at_curs)
  else 
    local selected_match = vim.api.nvim_buf_get_lines(c_bufnr, match_row, match_row + 1, true)[1] 
    local word_start_col = M.get_word_start_col(curs_col, #word_at_curs)
    vim.api.nvim_buf_set_text(0, curs_row - 1, word_start_col, curs_row - 1, curs_col, {selected_match}) 
    M.undo_newline(curs_row, word_start_col, #selected_match)
  end
  vim.api.nvim_buf_set_lines(c_bufnr, 0, -1, true, {})  
end 


---@param key string
---@param c_bufnr number 
---@param state table
M.completion = function(key, c_bufnr, state)
  local mode = vim.fn.mode()

  if mode == "n" then 
    state.word_at_curs = ""
    state.typed = false 
    state.match_row = 0
    vim.api.nvim_buf_set_lines(c_bufnr, 0, -1, true, {})

    -- get matches for the 'word_at_curs' (SUBSTR FROM curs_col TO FIRST NON-ALPHANUM CHAR!!!)
    -- when entering Insert mode
    if key == "i" then 
      state.word_at_curs = M.get_word_at_curs(state.curs_col)
      M.search_and_show_matches(c_bufnr, state.trie_root, state.word_at_curs)
    end 

    vim.schedule(function()
      state.curs_row, state.curs_col = unpack(vim.api.nvim_win_get_cursor(0))
    end)


  elseif mode == "i" then 
    if Keys.is_valid_key(key) then 
      state.word_at_curs = M.handle_valid_keys(key, c_bufnr, state.trie_root, state.word_at_curs, state.curs_col)
      state.typed = true 
      state.match_row = 0
      vim.schedule(function()
        state.curs_row, state.curs_col = unpack(vim.api.nvim_win_get_cursor(0))
      end)

    elseif key == Keys.RK.backspace and #state.word_at_curs > 0 then
      state.word_at_curs, state.curs_col = M.handle_deletion(c_bufnr, state.trie_root, state.word_at_curs, state.curs_col)
      state.match_row = 0

    elseif Keys.is_word_saving_key(key) then 
      if key == Keys.RK.escape then 
        state.typed = false
      end 
      
      M.handle_word_saving_key(c_bufnr, state.trie_root, state.word_at_curs, state.typed) 
      state.match_row = 0
      state.word_at_curs = ""

    elseif key == Keys.RK.enter then 
      M.handle_match_insertion(c_bufnr, state.trie_root, state.word_at_curs, state.curs_row, state.curs_col, state.match_row)
      state.word_at_curs = ""
      state.match_row = 0
       
    elseif (key == Keys.RK.down or key == Keys.RK.up) and Comp.matches_exist_in_buf(c_bufnr) then 
      vim.api.nvim_buf_clear_namespace(c_bufnr, 0, state.match_row, -1) -- delete previous highlight
      state.match_row = M.get_new_match_row(key, state.match_row, c_bufnr)
      vim.schedule(function()
        vim.api.nvim_win_set_cursor(0, {state.curs_row, state.curs_col})
      end)
    end 
  end  
  Conf.highlight_match(c_bufnr, state.match_row)
end 



return M 

