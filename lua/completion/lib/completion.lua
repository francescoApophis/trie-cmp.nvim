local v = vim.api

local M = {}

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
---@return string word_at_curs
M.get_word_at_curs = function(curs_col) 
  local curr_line_until_curs = string.sub(v.nvim_get_current_line(), 1, curs_col)
  return curr_line_until_curs:match("[%_*%w*]*$") or ""
end 


---@param c_bufnr number 
---@param state table
M.handle_deletion = function(c_bufnr, state)
  local word_at_curs = M.get_word_at_curs(v.nvim_win_get_cursor(0)[2])
  if #word_at_curs < 1 then 
    return
  end

  word_at_curs = word_at_curs:sub(1, #word_at_curs - 1)
  M.search_and_show_matches(c_bufnr, state.trie_root, word_at_curs)
  state.match_row = -1
end 


---@param c_bufnr number 
---@param state table
M.handle_word_saving_key = function(key, c_bufnr, state)
  if key == Keys.RK.enter and not state.enter_key_remap_disabled then
    return
  end
  -- avoid saving current word_at_curs after entering and exiting right away I-mode on a word 
  local word_at_curs = M.get_word_at_curs(v.nvim_win_get_cursor(0)[2])
  if state.valid_key_typed then 
    Trie.add_word(state.trie_root, word_at_curs)
  end 
  v.nvim_buf_set_lines(c_bufnr, 0, -1, true, {})
  state.valid_key_typed = false
  state.match_row = -1 
end 


---@param key string 
---@param state table
--- called in handle_up_arrow_keys()
M.prepare_match_insertion = function(c_bufnr, state)
  vim.keymap.set('i', '<Enter>', function() M.insert_match(c_bufnr, state) end, {noremap = true, silent = true})
  state.enter_key_remap_disabled = false
end

---@param c_bufnr number
---@param state table
M.insert_match = function(c_bufnr, state)
  local curs_row, curs_col = unpack(v.nvim_win_get_cursor(0))
  local match = v.nvim_buf_get_lines(c_bufnr, state.match_row, state.match_row + 1, true)[1] 
  local word_at_curs = M.get_word_at_curs(curs_col)
  local match_suffix = match:sub(#word_at_curs + 1) .. ' '
  v.nvim_buf_set_text(0, curs_row - 1, curs_col, curs_row - 1, curs_col, {match_suffix})

  vim.keymap.set('i', '<Enter>', Keys.RK.enter, {noremap = true, silent = true})
  state.enter_key_remap_disabled = true
  v.nvim_win_set_cursor(0, {curs_row, curs_col + #match_suffix})
  v.nvim_buf_set_lines(c_bufnr, 0, -1, true, {})
  state.valid_key_typed = false 
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
  word_at_curs = M.get_word_at_curs(v.nvim_win_get_cursor(0)[2]) .. key
  state.valid_key_typed = true 
  state.match_row = -1
  M.search_and_show_matches(c_bufnr, state.trie_root, word_at_curs)
end 


---@param key string 
---@param c_bufnr number
---@param state table
M.handle_ud_arrow_keys = function(key, c_bufnr, state)
  if not Comp.matches_exist_in_buf(c_bufnr) then
    return
  end

  if state.match_row ~= -1 then
    v.nvim_buf_clear_namespace(c_bufnr, 0, state.match_row, -1) 
  end

  local curs_row, curs_col = unpack(v.nvim_win_get_cursor(0))
  state.match_row = M.get_new_match_row(key, state.match_row, c_bufnr)
  M.prepare_match_insertion(c_bufnr, state)

  vim.schedule(function()
    v.nvim_win_set_cursor(0, {curs_row, curs_col})
  end)

  Conf.highlight_match(c_bufnr, state.match_row)
end

---@param key string 
---@param c_bufnr number
---@param state table
M.handle_lr_arrow_keys = function(key, c_bufnr, state)
  if key == Keys.RK.left or key == Keys.RK.right then 
    local curs_col = v.nvim_win_get_cursor(0)[2]
    curs_col = (key == Keys.RK.right and curs_col + 1) or curs_col - 1
    local word_at_curs = M.get_word_at_curs(curs_col)
    state.match_row = -1
    M.search_and_show_matches(c_bufnr, state.trie_root, word_at_curs)
  end
end

---@param key string 
---@param c_bufnr number
---@param state table
M.handle_insert_mode = function(key, c_bufnr, state)
  if Keys.is_valid_key(key) then 
    M.handle_valid_keys(key, c_bufnr, state)
  elseif key == Keys.RK.backspace then
    M.handle_deletion(c_bufnr, state)
  elseif Keys.is_word_saving_key(key) then 
    M.handle_word_saving_key(key, c_bufnr, state) 
  elseif key == Keys.RK.down or key == Keys.RK.up then 
    M.handle_ud_arrow_keys(key, c_bufnr, state)
  elseif key == Keys.RK.left or key == Keys.RK.right then 
    M.handle_lr_arrow_keys(key, c_bufnr, state)
  end
end

---@param key string 
---@param c_bufnr number
---@param state table
M.handle_normal_mode = function(key, c_bufnr, state)
  state.valid_key_typed = false 
  state.match_row = -1
  v.nvim_buf_set_lines(c_bufnr, 0, -1, true, {})

  if not state.enter_key_remap_disabled then 
    for _, keymap in ipairs(v.nvim_get_keymap('i')) do
      if keymap['lhs'] == '<CR>' and keymap['callback'] then
        vim.keymap.set('i', '<Enter>', Keys.RK.enter, {noremap = true, silent = true})
        state.enter_key_remap_disabled = true
      end
    end
  end

  if key == "i" then
    local curs_col = v.nvim_win_get_cursor(0)[2]
    word_at_curs = M.get_word_at_curs(curs_col)
    M.search_and_show_matches(c_bufnr, state.trie_root, word_at_curs)
  end
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

