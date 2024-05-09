---@meta Lua_Trie
local M = {}

M.new_node = function(self, char)
 o = {
   char = char or "",
   children = {},
   last_char = false,
 }

 setmetatable(o, self)
 self.__index = self 
 return o 
end  



---@param str string 
---@return string[] 
M.str_to_arr = function(str)
  arr = {}
  for char in string.gmatch(str, ".") do table.insert(arr, char) end
  return arr 
end 

---@param trie_node table 
---@param word string | string[]
---@param idx  number | nil
---@return nil
M.add_word = function(trie_node, word, idx)
  idx = idx or 1

  if type(word) ~= "table" then 
    word = M.str_to_arr(word)
  end

  if idx > #word then 
    trie_node.last_char = true
    return 
  end
  
  curr_char = word[idx]
  local i = 1

  while i < (#trie_node.children + 1) do 
    local child = trie_node.children[i]
    if curr_char == child.char then 
      M.add_word(child, word, idx + 1)
      break
    end 
    i = i + 1
  end 

  if i == (#trie_node.children + 1) then 
    -- new_node = {char = curr_char, children = {}, last_char = false}
    table.insert(trie_node.children, M:new_node(curr_char))
    M.add_word(trie_node.children[#trie_node.children], word, idx + 1 )
  end
end 



---@param trie_node table
---@word string 
---@idx number | nil
---@return boolean | nil 
M.delete_full_word = function(trie_node, word, idx) 
  idx = idx or 1
  local char = word:sub(idx, idx)
  
  if #char == 0 then 
    return false
  end 
  
  for i, child in ipairs(trie_node.children) do 
    if child.char == char then 
      local deleted = M.delete_full_word(child, word, idx + 1)
      
      -- word doesn't exist
      if deleted == nil then return nil end 
      
      if not deleted then 
        -- parsed branch is a compound word and word to delete is its stem 
        if child.last_char and #child.children > 0 then 
          child.last_char = false
          return true
        end 

        table.remove(trie_node.children, i)

        -- parsed branch is a compound word and word to delete is its suffix  
        if trie_node.last_char then return true end
      end

      if #trie_node.children > 0 then return true end 

      return false
    end 
  end 

  return nil
end 


---@param trie_node table
---@param original_word string 
---@param idx number | nil 
---@return boolean | nil
M.delete_last_char_from_word = function(trie_node, original_word, idx)
  idx = idx or 1 
  local char = original_word:sub(idx, idx)

  if #char == 0 then 
    return false
  end 

  for i, child in ipairs(trie_node.children) do 
    if child.char == char then
      local deleted = M.delete_last_char_from_word(child, original_word, idx + 1)

      if deleted == nil then return nil end 

      if not deleted then 
        -- deleting last char from word that is stem of other compound words
        if child.last_char and #child.children > 0 then 
          child.last_char = false
          return true
        end 
        
        -- this will avoid deleting one of the children nodes of root 
        -- (thus deleting entire braches) if you type a single letter
        -- as a new word and delete it right after 
        if #original_word > 1 then
          table.remove(trie_node.children, i)
        end

        if #original_word - 1 > 1 then 
          trie_node.last_char = true
        end 
        return true

      else
        return deleted
      end
    end 
  end 
  return nil 
end 

---@param trie_node table
---@param pattern string
---@param all_matches string[] 
---@return string[] 
M.dfs_and_stringify_matches = function(trie_node, pattern, all_matches)
  if trie_node.char == "" then 
    return 
  end 

  all_matches = all_matches or {}

  if trie_node.last_char then  
    table.insert(all_matches, pattern .. " ")
  end 
  
  for _, child in ipairs(trie_node.children) do 
    pattern = pattern .. child.char
    M.dfs_and_stringify_matches(child, pattern, all_matches)
    pattern = string.sub(pattern, 1, #pattern - 1)
  end 
  
  return all_matches
end 


---@param trie_node table 
---@param pattern string
---@param pattern_arr string[] | nil 
---@param idx number | nil  
---@return string[] | nil
M.get_all_matches = function(trie_node, pattern, pattern_arr, idx)
  if #pattern < 1 then return end -- empty string

  idx = idx or 1 
  pattern_arr = pattern_arr or M.str_to_arr(pattern)

  if idx > #pattern_arr then 
    return M.dfs_and_stringify_matches(trie_node, pattern)
  end

  local curr_char = pattern_arr[idx]

  for _, child in ipairs(trie_node.children) do  
    if curr_char == child.char then
      -- go the last trie-node with char as current char in pattern 
      return M.get_all_matches(child, pattern, pattern_arr, idx + 1)
    end 
  end
end 


-- Show only indented trie_node.chars and a dot for trie_node.last_char value
---@param trie_node table
---@param depth number | nil
---@return nil
M.simple_pretty_print = function(trie_node, depth)
  depth = depth or 1

  indent = ""
  for i=1,depth do 
    indent = indent .. "  "
  end 

  print(indent, trie_node.char, (trie_node.last_char and ".") or "") 

  for _, child in ipairs(trie_node.children) do
    M.simple_pretty_print(child, depth + 1)
  end 
end 



---@param trie_node table
---@depth number | nil
---@return nil
M.pretty_print = function(trie_node, depth)
  depth = depth or 0

  local indent = ""
  for i=1,depth do 
    indent = indent .. "      "
  end 
  
  if trie_node.char == "" then 
    print(indent, "ROOT:")
  else 
    print("\n")
    print(indent, "char:", trie_node.char)
    print(indent, "last_char:", trie_node.last_char)
  end 

  print(indent, "children: { ", (#trie_node.children < 1 and "}") or "")

  for _, child in ipairs(trie_node.children) do
    M.pretty_print(child, depth + 1)
  end   
  print(indent, (trie_node.char ~= "" and "},") or "}")
end 



---@return string[]
M.get_all_methods_names = function() 
  local methods_names = {}

  for k, v in pairs(M) do 
    if type(v) == "function" then  
      print(string.format("%s()", k))
    end 
  end
end 


return M  

