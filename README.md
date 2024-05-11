# trie-cmp.nvim 

## **THIS IS A TOY PROJECT**


## Text-completion through a Trie (Prefix Tree) in Lua.
The completion suggest just words and it's context-less, so suggestion are 
displayed in no particular order.
The experience basically mimics the built-in text-completion of Neovim.  

## Usage
Use the commands ```:CompOn``` to start the completion, ```:CompOff``` to stop it .

A Trie is created at the start and if the opened buffer 
is a normal file buffer, every word containing **letters** **numbers** and **underscores** 
will be saved in it. The Trie will be cleared once the completion is stopped. 

New words are saved in the Trie whenever spaces/indents or punctuation (besides *underscore*) are inserted or 
Insert mode is exited **right after typing the words**.

Move through the suggestion with **arrow-Up/Down**. 

***At the moment there is no customization available***


## Installation 
Keep in mind that I know nothing about plugin managers. ***I think*** (not sure)
the plugin  would work at the moment only with **Lazy.nvim**. 

```lua
return {
    "francescoApophis/trie-cmp.nvim",
    lazy = false,
}
```





