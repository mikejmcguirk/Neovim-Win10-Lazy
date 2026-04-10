## General

#### TODO:

- [ ] https://github.com/neovim/neovim/commit/9c5fba5df0b60cd25ac2c180a7d82fca47a105e6 - Does this prompt anything?
- [ ] Change these keys over - https://github.com/neovim/neovim/commit/3a4a66017b74192caaf9af9af172bdc08e0c1608
- [ ] Do these, collectively, prompt anything?:
  - https://github.com/neovim/neovim/commit/446e794a9c8823040b8d41fc86a1bc3bb99508e7
  - https://github.com/neovim/neovim/commit/1ff1973269594254900fbce40fd35c3024d9ed3d
  - https://github.com/neovim/neovim/commit/eaea0c0f9da38613a6b8e7f13e0cf4263f7e22f3
- [ ] Treesitter memory leak:
  - Can make it happen with my tests/minimal init
  - Related? - https://github.com/neovim/neovim/issues/14216
  - More cumbersome, but can make happen in Lua
  - Does not happen in text

- [ ] Got this error when going to the bottom of an md and pasting an image. Not sure where around the pasting this happened.
  - Got it again when like, you paste the image on not the last line, save, and then the last line is removed before saving
  Decoration provider "range" (ns=nvim.treesitter.highlighter):
  Lua: /usr/local/share/nvim/runtime/lua/vim/treesitter.lua:212: Index out of bounds
  stack traceback:
    [C]: in function 'nvim_buf_get_text'
    /usr/local/share/nvim/runtime/lua/vim/treesitter.lua:212: in function 'get_url'
    ...al/share/nvim/runtime/lua/vim/treesitter/highlighter.lua:439: in function 'fn'
    ...al/share/nvim/runtime/lua/vim/treesitter/highlighter.lua:245: in function 'for_each_highlight_state'
    ...al/share/nvim/runtime/lua/vim/treesitter/highlighter.lua:361: in function <...al/share/nvim/runtime/lua/vim/treesitter/highlighter.lua:335>
    [C]: in function 'nvim_cmd'
    /home/mjm/.config/nvim/lua/mjm/stl.lua:149: in function </home/mjm/.config/nvim/lua/mjm/stl.lua:142>
  Decoration provider "range" (ns=nvim.treesitter.highlighter):
  Lua: /usr/local/share/nvim/runtime/lua/vim/treesitter.lua:212: Index out of bounds
  stack traceback:
    [C]: in function 'nvim_buf_get_text'
    /usr/local/share/nvim/runtime/lua/vim/treesitter.lua:212: in function 'get_url'
    ...al/share/nvim/runtime/lua/vim/treesitter/highlighter.lua:439: in function 'fn'
    ...al/share/nvim/runtime/lua/vim/treesitter/highlighter.lua:245: in function 'for_each_highlight_state'
    ...al/share/nvim/runtime/lua/vim/treesitter/highlighter.lua:361: in function <...al/share/nvim/runtime/lua/vim/treesitter/highlighter.lua:335>
    [C]: in function 'nvim_cmd'
    /home/mjm/.config/nvim/lua/mjm/stl.lua:135: in function </home/mjm/.config/nvim/lua/mjm/stl.lua:108>
    [C]: in function 'nvim_exec_autocmds'
    /usr/local/share/nvim/runtime/lua/vim/diagnostic.lua:1456: in function 'set'
    /usr/local/share/nvim/runtime/lua/vim/lsp/diagnostic.lua:253: in function 'handle_diagnostics'
    /usr/local/share/nvim/runtime/lua/vim/lsp/diagnostic.lua:266: in f

#### MID:

- [ ] Re-implement dynamic documentHighlight
  - Reasoning: I use this enough that it would side-step some amount of manual input
  - [ ] Question: How does this marry with my grh map?
    - Perhaps use grh to toggle dynamic highlighting, then grH to manually show the highlight if one exists

- [ ] I'm not sure how you do this, but if you select multiple lines in visual line mode, and maybe block mode as well, nvim-surround should apply per line rather than the whole selection
  - There's a multi-cursor map for creating multiple cursors based on a visual selection. This feels like the easiest way to do it
    * This creates an interesting question though of what the actual best solution is. If you assume Neovim will support multicursor (on the roadmap), it follows then that "by line" functionality should be routed there. On the other hand, you have the default "Q" mapping in visual mode, which applies macros by line. It also feels bad, in general, to have to stand-up multiple cursors to do something simple
      + Counterpoint though, if you say that "v" is whole selection and "V"/"\22" are by line, you're creating a new sub-grammar. Or if you use different keys to do whole selection or by line, that's something you have to learn per map/per plugin. So, really, multi-cursor is probably the most principled solution here.

- [ ] Try to make dynamic rnu again
  - Blockers:
    - [ ] My file opening is in flux, so I don't want to chase a moving target
    - [ ] For the open file methods I use, I need to understand when the different parts of the process happen, so I know what I'm missing that's causing the flaky rnu appearance
  - Requirements:
    * [ ] Cannot require layering a bunch of hacks on top of each other that create complexity surface area.
    * [ ] Must be centralized. Cannot require setting nu/rnu in every problem filetype

- [ ] https://github.com/neovim/neovim/pull/38344
  * [ ] Does this affect my document color setup?
  * [ ] A lot of commentary in general that's worth parsing thorugh

- [ ] The gF text-tool function needs to be able to handle multiple lines in visual mode
- [ ] The blink.cmp dictionary removed the plenary dep. Try installing again and see if the hung fzf issue still appears
- [ ] % on quotation marks does not go to the matching quote
- [ ] https://github.com/ribru17/ts_query_ls (and download build that disables built-in linter)
- [ ] https://github.com/neovim/neovim/pull/27223 - Replace any instances of tabnew with nvim_open_tabpage
- [ ] https://github.com/neovim/neovim/commit/4d04d0123d2571391a00b87f7ee70f987fb7cedd
  - Can this be used to make colorscheme more performant?
- [ ] Implement table_new in this config
  - [ ] Make it variable based on if `jit` is present so that this can be opened in non-JIT builds
- [ ] https://github.com/neovim/neovim/pull/37141
  - Does this create an issue with comma fillchars? If so, make a PR?
- [ ] Replace write cmd to scratch buffer custom code
  * [ ] This thread contains ideas on how to re-direct cmd output to a buffer: https://github.com/neovim/neovim/issues/30376. Research and pick the best one
  * [ ] Implement the chosen idea
* [ ] "gx"able URLs in markdown are not underlined. How can this be fixed?
* [ ] For prose buffers (md and text), should the option sets and insert `<C-g>u` mappings be outlined into utils? The options I think are fine, since I don't see why they would be different, but I've never loved the insert maps to begin with, and since Markdown is more "syntaxy" I'm not sure they should be the same
- [ ] The jumplist should not inherit bufs from other sessions
  * Starting it fresh each time is acceptable
- [ ] The new float statusline would be useful to show win info/buf info
- [ ] @nomarkdown is considered two separate words for markdown line wrapping. Why?

#### LOW:

- [ ] The guard against running due to autocomplete windows could be more specific
  - Check for nofile?
    * Tricky, because while nofile buffers cannot show in the tabline, you do need to know if you are entering one to make sure none of the tabline buffers show as current
  - Counterpoint: It works
- [ ] The harpoon component should be stored as a data structure. This allows events to make targeted changes, rather than completely regenerating it
  - [ ] BufWritePost would only need to update the event buf
- [ ] Make the tal a pure Lua expression
  - Problem: The expression runs on every keystroke, which is correct for build_tabpage_component, but would be too much for the harpoon component.
  - [ ] The harpoon component would need to be built in the background and cached, with the Lua expression picking up that cache. And then the cached value would be updated on event as it currently is.
- [ ] It would be good if the harpoon tabline component were generalizable and could be stuck into other plugins
  - [ ] Example: https://github.com/mike-jl/harpoonEx/blob/main/lua/lualine/components/harpoons/init.lua
- [ ] How to do document exports. pandoc? 2html? Is there a plugin?
* [ ] What is secure mode and what does it do?

## Maps

#### TODO:

- [ ] Use [<C-t> and ]<C-t> for tabmove
  - [ ] Should this take a wrapping count?
    - Unlike qf-navigation, where you can go back, a mis-handled tab move creates a confusing arrangement of tabs. Might be better to just clamp at ends
    - [ ] If not wrapping count, use +/- args

#### MID:

- [ ] Should ]t be gT or tabnext?
  - [ ] It's arbitrary for gT to be count back, whereas gt is absolute count
    - [ ] The defaults, though, are this way
  - [ ] Would sync with [Q]Q, where count on either is absolute count
    - [ ] On the other hand, This is also not capital
  - [ ] Alternative: Make both [t and ]t wrap, then use [T]T for absolutes. Would sync with qf

- [ ] The visual move map, in markdown, can break nested indentation
  - Perhaps you only get the indentation of the first line, then adjust everything else based on that
  - [ ] More big picture, using equalprg for indentation is bad because it blows up dot repeat. There is probably an opportunity here to exercise the nvim-tools indent function
  - [ ] Perhaps it is time to move on from using the :move command completely. This can 100% be done using the API
    - One immediate question though is how to handle extmarks. I wonder if :move also moves them, in which case we would need a way to do that.
- [ ] Figure out a way to save sessions that works, tie restart and restart mappings into sessions:
  - https://www.reddit.com/r/neovim/comments/1shks8o/nvim_012s_new_restart_command_is_nice/ - Thoughts on how to configure this with mksession. Includes commentary from echasnovski
  - r<bs> restart map suggestion. Not sure if this works due to mode recognition, but creative! - https://x.com/Neovim/status/2042611217328423011

#### MAYBE:

- Use a harpoon-style buffer to edit tabpages

## Plugins

#### TODO:

- I currently have Harpoon configured to display filenames only in the tabline. If duplicate filenames are found, it should display relative paths.

#### MID:

- [ ] Archived, but an nvim matchparen implementation - https://github.com/utilyre/sentiment.nvim
  - Do I just rewrite the core matchparen in Lua then expand upon it for my own purposes? The matchup.vim plugin creates issues

#### LOW:

* [ ] mini.splitjoin instead of treesj?

## ui2

#### TODO:

- If I do `imap <C-u>` it opens the pager (I think) with the result on multiple lines. I hit `<C-c>` once and it minimizes the pager, but then I need to hit `<C-c>` again to clear the line
  - [ ] There should be a way to make closing the pager and clearing the cmdline the same cmd

#### MID:

- [ ] If I `g<` into a pager window then leave or quit, it should go back to the previously used window
  * [ ] Check first if this is a settings issue. Maybe it's a problem if I have useopen before uselast
  * [ ] If it's not a settings issue, then, why wouldn't it work? Hate to open an issue without at least a suggestion on what to do. It feels like this would be the kind of thing that's a somewhat obscure bug.
* [ ] Why does hitting enter with a pager window open cause me to go into the pager. I think this is intended behavior, but I'd rather overwrite it. Should only be g< to enter

#### MAYBE:

* [ ] Submit an issue for pager buffers being modifiable
  * I can't imagine that (a) this is intended behavior and (b) no one has noticed this. My guess is that, since nomodifiable buffers can't even be written to programmatically, this is currently allowed so it doesn't become a development chokepoint

## LSP

#### TODO:

- https://github.com/neovim/neovim/commit/f9e068117be9c6ca05d3e42530895449cbdc2a17
  * This prompts a change in my own code since I no longer have to deal with this use case
  * I know there are other things in my plugins that have to factor this in. Do a scan through the other todo lists to see if they are out there
  * This change has something else built into it that I need to look at again

#### MID:

* [ ] grA
  * Whole buffer scoped code actions?
