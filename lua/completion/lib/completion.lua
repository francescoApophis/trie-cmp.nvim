local M = {}

local v = vim.api


---@param c_bufnr number 
---@param trie_root trie_node
---@param word_at_curs string 
M.search_and_show_matches = function (c_bufnr, trie_root, word_at_curs)
  v.nvim_buf_set_lines(c_bufnr, 0, -1, true, {} ) -- DELETE ALL PREVIOUS MATCHES

  local matches = Trie.get_all_matches(trie_root, word_at_curs)
  if matches then 
    v.nvim_buf_set_lines(c_bufnr, 0, -1, true, matches) 
  end 
end  

---@param c_bufnr number 
---@return boolean first_line_in_c_bufnr
M.matches_exist_in_buf = function(c_bufnr) 
  return v.nvim_buf_get_lines(c_bufnr, 0, 1, true)[1] ~= "" 
end 


---@param trie_root trie_node
M.save_words_from_opened_buf = function(trie_root)
  local new_buf_lines = vim.fn.readfile(vim.fn.bufname())
  if #new_buf_lines < 1 then return end  

  for i, line in ipairs(new_buf_lines) do 
    for word in line:gmatch("[%_*%w*]*") do 
      if #word > 1 then  Trie.add_word(trie_root, word) end 
    end 
  end 
end 


---@param key string 
---@match_row number 
---@param c_bufnr number 
---@return number match_row 
M.get_new_match_row = function(key, match_row, c_bufnr)
  local c_bufnr_len = v.nvim_buf_line_count(c_bufnr)
  if key == Keys.RK.down then 
    return (match_row + 1 >= c_bufnr_len and -1) or match_row + 1
  end 
  return (match_row - 1 < -1 and c_bufnr_len - 1) or match_row - 1
end 


---@param curs_col number 
---@param word_at_curs_len number 
---@return number match_row 
M.get_word_start_col = function(curs_col, word_at_curs_len)
  if curs_col - word_at_curs_len < 0 then 
    return 0
  elseif (curs_col - word_at_curs_len) == curs_col then  
    return curs_col - #M.get_word_at_curs(curs_col) 
  end 
  return curs_col - word_at_curs_len 
end 


---@param curs_col number 
---@return string word_at_curs
M.get_word_at_curs = function(curs_col) 
  local curr_line_until_curs = string.sub(v.nvim_get_current_line(), 1, curs_col)
  return curr_line_until_curs:match("[%_*%w*]*$") or ""
end 



---@param key string 
---@param curs_col number
---@return number curs_col 
M.get_new_curs_col_for_arrows_lr = function(key, curs_col)
  curs_col = (key == Keys.RK.left and curs_col - 1) or (key == Keys.RK.right and curs_col + 1)
  if curs_col < 0 then 
    return  0 
  end 

  if curs_col >= vim.fn.strlen(vim.fn.getline(".")) then 
    return vim.fn.strlen(vim.fn.getline("."))
  end 
  
  return curs_col 
end 



---@param c_bufnr number 
---@param state table
M.handle_deletion = function(c_bufnr, state)
  state.word_at_curs = string.sub(state.word_at_curs, 1, #state.word_at_curs - 1)
  M.search_and_show_matches(c_bufnr, state.trie_root, state.word_at_curs)
  state.match_row = -1
  state.curs_col = (state.curs_col - 1 < 0 and 0) or state.curs_col - 1 -- what it you delete and go line above?
end 


---@param c_bufnr number 
---@param state table
M.handle_word_saving_key = function(c_bufnr, state)
  -- avoid saving current word_at_curs after entering and exiting right away I-mode on a word 
  if  state.valid_key_typed and #state.word_at_curs > 1 then 
    Trie.add_word(state.trie_root, state.word_at_curs)
  end 
  state.valid_key_typed = false
  state.match_row = -1 
  state.word_at_curs = ""
end 



---@param c_bufnr number
---@param state table
M.insert_match = function(c_bufnr, state)
  if not M.matches_exist_in_buf(c_bufnr) then
    Trie.add_word(state.trie_root, state.word_at_curs)
    return curs_col
  end 

  local match = v.nvim_buf_get_lines(c_bufnr, state.match_row, state.match_row + 1, true)[1] 
  local match_suffix = match:sub(#state.word_at_curs + 1) .. ' '
  v.nvim_buf_set_text(0, state.curs_row - 1, state.curs_col, state.curs_row - 1, state.curs_col, {match_suffix})
  vim.keymap.set('i', '<Enter>', Keys.RK.enter, {noremap = true, silent = true})
  v.nvim_win_set_cursor(0, {state.curs_row, state.curs_col + #match_suffix})
end 


--- grab word/s have been deleted from the curr buffer from '"' register that
--- and deleted from the Trie as well. Currently only if they got deleted through v/V-Line modes
---@param trie_root trie_node
M.remove_deleted_words = function(trie_root)
  vim.schedule(function()
    local last_deleted = vim.fn.getreg('"'):gsub("\\n", "", 1)

    for word in last_deleted:gmatch("[%_*%w*]*") do 
      -- only if there is no other occurrence of the word in curr buffer
      if vim.fn.search(word, "n") == 0 then 
        Trie.delete_full_word(trie_root, word)
      end
    end 
  end) 
end 




---@param key string 
---@param c_bufnr number
---@param state table
M.handle_valid_keys = function(key, c_bufnr, state)
  state.word_at_curs = state.word_at_curs .. key
  state.valid_key_typed = true 
  state.match_row = -1
  M.search_and_show_matches(c_bufnr, state.trie_root, state.word_at_curs)

  vim.schedule(function()
    state.curs_row, state.curs_col = unpack(v.nvim_win_get_cursor(0)) 
  end)
end 

---@param key string 
---@param state table
M.prepare_match_insertion = function(c_bufnr, state)
  vim.keymap.set('i', '<Enter>', function() M.insert_match(c_bufnr, state) end, {noremap = true, silent = true})
end


---@param key string 
---@param c_bufnr number
---@param state table
M.handle_ud_arrow_keys = function(key, c_bufnr, state)
  if (key == Keys.RK.down or key == Keys.RK.up) and Comp.matches_exist_in_buf(c_bufnr) then 
    v.nvim_buf_clear_namespace(c_bufnr, 0, state.match_row + 1, -1) 
    state.match_row = M.get_new_match_row(key, state.match_row, c_bufnr)
    M.prepare_match_insertion(c_bufnr, state)

    Conf.highlight_match(c_bufnr, state.match_row)
    vim.schedule(function()
      v.nvim_win_set_cursor(0, {state.curs_row, state.curs_col})
    end)
  end
end

---@param key string 
---@param c_bufnr number
---@param state table
M.handle_lr_arrow_keys = function(key, c_bufnr, state)
  if key == Keys.RK.left or key == Keys.RK.right then 
    state.curs_col = M.get_new_curs_col_for_arrows_lr(key, state.curs_col)
    state.word_at_curs = M.get_word_at_curs(state.curs_col)
    M.search_and_show_matches(c_bufnr, state.trie_root, state.word_at_curs)
  end
end

---@param key string 
---@param c_bufnr number
---@param state table
M.handle_insert_mode = function(key, c_bufnr, state)
  if Keys.is_valid_key(key) then 
    M.handle_valid_keys(key, c_bufnr, state)
  elseif key == Keys.RK.backspace and #state.word_at_curs > 0 then
    M.handle_deletion(c_bufnr, state)
  elseif Keys.is_word_saving_key(key) then 
    M.handle_word_saving_key(c_bufnr, state) 
  elseif (key == Keys.RK.down or key == Keys.RK.up) and Comp.matches_exist_in_buf(c_bufnr) then 
    M.handle_ud_arrow_keys(key, c_bufnr, state)
  elseif key == Keys.RK.left or key == Keys.RK.right then 
    M.handle_lr_arrow_keys(key, c_bufnr, state)
  end
end

---@param key string 
---@param c_bufnr number
---@param state table
M.handle_normal_mode = function(key, c_bufnr, state)
  state.word_at_curs = ""
  state.valid_key_typed = false 
  state.match_row = -1
  v.nvim_buf_set_lines(c_bufnr, 0, -1, true, {})

  if key == "i" then
    state.word_at_curs = M.get_word_at_curs(state.curs_col)
    M.search_and_show_matches(c_bufnr, state.trie_root, state.word_at_curs)
  end

  vim.schedule(function()
    state.curs_row, state.curs_col = unpack(v.nvim_win_get_cursor(0))
  end)
end

---@param key string
---@param c_bufnr number 
---@param state table
M.completion = function(key, c_bufnr, state)
  local mode = vim.fn.mode()

  if mode == "n" then 
    M.handle_normal_mode(key, c_bufnr, state)
  elseif mode == "v" or mode == "V" and (key == "d" or key == "D") then 
    M.remove_deleted_words(state.trie_root)
  elseif mode == "i" then 
    M.handle_insert_mode(key, c_bufnr, state)
  end
end 

return M 

