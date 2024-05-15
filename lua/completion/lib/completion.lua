local M = {}

---@alias trie_node
---| '"char"' 
---| '"children"' 
---| '"last_char"' # Is the last character of the word


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
    for word in line:gmatch("[%_*%w*]*") do 
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
  elseif (curs_col - word_at_curs_len) == curs_col then  
    return curs_col - #M.get_word_at_curs(curs_col) 
  end 
  return curs_col - word_at_curs_len 
end 
 
---@param curs_col number 
---@return string word_at_curs
M.get_word_at_curs = function(curs_col) 
  local curr_line_until_curs = string.sub(vim.api.nvim_get_current_line(), 1, curs_col)
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
---@param valid_key_typed boolean If the user has typed any new letters
M.handle_word_saving_key = function(c_bufnr, trie_root, word_at_curs, valid_key_typed)
  -- avoid saving current word_at_curs after having entered Insert mode on a word 
  -- and exiting right away with Escape, a word_saving_key
  if not valid_key_typed then 
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


--- grab word/s have been deleted from the curr buffer from '"' register that
--- and deleted from the Trie as well. Currently only if they got deleted through v/V-Line modes
---@param trie_root trie_node
---@return nil
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
M.completion = function(key, c_bufnr, state)
  local mode = vim.fn.mode()

  if mode == "n" then 
    state.word_at_curs = ""
    state.valid_key_typed = false 
    state.match_row = 0
    vim.api.nvim_buf_set_lines(c_bufnr, 0, -1, true, {})

    -- get matches for the 'word_at_curs' (substr from curs_col to first non-alphanum char)
    -- when entering Insert mode
    if key == "i" then
      state.word_at_curs = M.get_word_at_curs(state.curs_col)
      M.search_and_show_matches(c_bufnr, state.trie_root, state.word_at_curs)
    end

    vim.schedule(function()
      state.curs_row, state.curs_col = unpack(vim.api.nvim_win_get_cursor(0))
    end)


  elseif mode == "v" or mode == "V" and (key == "d" or key == "D") then 
    M.remove_deleted_words(state.trie_root)


  elseif mode == "i" then 
    if Keys.is_valid_key(key) then 
      state.word_at_curs = M.handle_valid_keys(key, c_bufnr, state.trie_root, state.word_at_curs, state.curs_col)
      state.valid_key_typed = true 
      state.match_row = 0
      vim.schedule(function()
        state.curs_row, state.curs_col = unpack(vim.api.nvim_win_get_cursor(0))
      end)

    elseif key == Keys.RK.backspace and #state.word_at_curs > 0 then
      state.word_at_curs, state.curs_col = M.handle_deletion(c_bufnr, state.trie_root, state.word_at_curs, state.curs_col)
      state.match_row = 0

    elseif Keys.is_word_saving_key(key) then 
      M.handle_word_saving_key(c_bufnr, state.trie_root, state.word_at_curs, state.valid_key_typed) 
      state.valid_key_typed = false
      state.match_row = 0
      state.word_at_curs = ""

      if key == Keys.RK.escape then 
        vim.schedule(function()
          state.curs_row, state.curs_col = unpack(vim.api.nvim_win_get_cursor(0))
        end)
      end 

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

    elseif key == Keys.RK.left or key == Keys.RK.right then 
      state.curs_col = M.get_new_curs_col_for_arrows_lr(key, state.curs_col)
      state.word_at_curs = M.get_word_at_curs(state.curs_col)
      M.search_and_show_matches(c_bufnr, state.trie_root, state.word_at_curs)
    end 
  end  

  Conf.highlight_match(c_bufnr, state.match_row)
end 



return M 

