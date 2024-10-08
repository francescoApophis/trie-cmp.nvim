# trie-cmp.nvim 

## **THIS IS A TOY PROJECT**

![trie-comp1-2024-05-11_03 05 47-ezgif com-video-to-gif-converter (1)](https://github.com/francescoApophis/trie-cmp.nvim/assets/111281477/df24839f-a3db-4948-b3c5-5b4f252ede04)


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

Move through the suggestion with *<arrow-Up/Down>*. Press *Enter* to insert suggestions in the current
buffer.

***At the moment there is no customization available***

## WARNING
If you have particular mappings for the \<Enter\> key in **INSERT** mode ***THE PLUGIN MIGHT CAUSE THOSE
MAPPINGS TO NOT WORK***

The plugin *temporarily* **REMAPS** the \<Enter\> key **ONLY WHEN IN INSERT MODE AFTER PRESSING 
UP/DOWN ARROWS KEYS** to allow suggestion insertion in the buffer. It **MAPS IT BACK RIGHT AFTER INSERTING**  
the selected suggestion (*after pressing \<Enter\>*).

Unfortunately, I had to use this workaround because of a bug I couldn't solve 
in the previous method I used.

## Requirements
- Neovim >= 0.9.5 (the version I've built the plugin on)

## Installation 
Keep in mind that I know nothing about plugin managers. ***I think*** (not sure)
the plugin  would work at the moment only with **Lazy.nvim**. 

```lua
return {
    "francescoApophis/trie-cmp.nvim",
    lazy = false,
}
```





