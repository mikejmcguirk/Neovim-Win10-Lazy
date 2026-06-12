## General

#### DEPS:

#### TODO:

- [ ] Add a way for harpoon to handle multiple lists. It is becoming obnoxious to re-build the lists for the variou sub-projects in here.
  - [ ] Use `<leader>a[` and `<leader>a]` to cycle lists.
  - [ ] And `<leader>a` something to bring up a list of lists.

- [ ] https://github.com/neovim/neovim/commit/9c5fba5df0b60cd25ac2c180a7d82fca47a105e6 - Does this prompt anything?
- [ ] More API buf changes - https://github.com/neovim/neovim/pull/38900
  - https://github.com/neovim/neovim/commit/d0af4cd9094f3439382622906da5b1c5cd82c294
  - https://github.com/neovim/neovim/commit/71ac4db335e00b03b27d2c4aa5ab90c083a3a3e7
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

- [ ] Need to figure out a way to have system default config files for stuff like stylua.toml

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

- [ ] Don't have a way to say, be in a buffer, see what made a change, then get the full git diff of that commit. I can use gitsigns blame to see the last change. Or I can use fzf-lua to pull old versions, but I can't get the diffs or like pull up the full old list of changes.
  - The use case here was, I knew in vim.iter() there was the change that added variadic generics, but I wasn't sure where the meta file was that had the Lua_Ls prototypes, so I wanted to use the commit info from iter.lua to get the list of changed files to see where the meta file was, and I just didn't have the stuff to get there.
- [ ] Needs to be some kind of Fugitive shortcut for "amend the last commit to advance it to the current state." Saves time/commits/pushes on cases where you need to fix a goof in the previous commit.

- [ ] https://github.com/wellle/targets.vim
  - Looks like it can solve the i| a| problem
  - Also an interesting thing where you can do di, and da, in text
  - Also this: https://github.com/kana/vim-textobj-user
  - Note in both of these, there are other ideas and some suggested mappings for them that are interesting
+ [ ] Grep the current visual selection in fzflua
- [ ] With stal = 0, ls = 0, disabling ts context, tmux commands, and window padding, you can make your own zen at home. Question - do you still just do it as a float or do you save the old window layout?
  - Unmerged winpadding PR: https://github.com/neovim/neovim/pull/37939
- [ ] For the intro scratch buffer, IMO it should either be set to be a noma scratch buffer or I should come up with a way that you can edit it and save it conveniently.
  - [ ] Caveat, I tried the scratch buffer thing before and there was some reason I ditched it, so I wouldn't just get rid of the current code until the new method has sat for a while.

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
  - https://github.com/neovim/neovim/issues/39552 - This pertains to an issue with job killing in vim.system, which seems relevant to the problem case that cause me to leave the dictionary completion source to begin with. Need to understand if this issue affects me there.
    * Most likely, I'll just need to try it with system monitor on. But still a good awareness item
- [ ] % on quotation marks does not go to the matching quote
- [ ] https://github.com/ribru17/ts_query_ls (and download build that disables built-in linter)
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
- [ ] https://github.com/neovim/nvim-lspconfig/commit/d50c6d53a40d5592b66a7ce989e0644fee51eeaa - Docs for how to add LSPConfig type annotations
- [ ] Is the new `scrolloffpad` option useful for my use case?

- [ ] https://github.com/neovim/neovim/commit/7fff439395215001ab74a96cc3df3d1b6d795177 - Does this make Nvim's built-in completion featureful enough to replace nvim-cmp?

- [ ] Potentially use `:h indent-guides`

- [ ] https://github.com/modem-dev/hunk - Diff viewing is becoming more of a chokepoint. I don't know what tools you put together to do it, but it needs to be like, you make a new tab in Nvim, and you have the list of changed files in the quickfix list, and when you open a file it opens a diff view, and if you use quickfix bracket navigation it keeps both windows updated.

- [ ] How do you jump to unsaved changes?

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
- [ ] https://github.com/ergodice/statuscol-oil.nvim

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

#### MID:

- [ ] Rename in moxide renames the entire buffer. This feels bad. There are some LSPs that support renaming files, that should have its own hotkey, and I guess moxide's rename command needs to be re-directed there.
- [ ] grA
  - Whole buffer scoped code actions?

## Rename

#### OBJECTIVES

- Experience
  * When performing a rename, an incremental, extmark-based preview will display
    + Show substitute highlighted text for the new name, ghost text for the old name
      + Stretch goal: Use inline space virtual text so the preview doesn't overlap with the old text
    + All teardown should be automatic when the user is done with rename input
    + The output should follow what the user does exactly
    + Folded lines should simply be ignored
    + The preview should show in all visible buffers in the current tabpage to which it applies
- Interface
  - should_prompt and new_name should be separate inputs
    * should_prompt == nil or should_prompt == true - prompt
    * should_prompt == false - rename immediately
    * If should_prompt and name == nil, use cword
    * If should_prompt and name == "", blank prompt
    * If no_prompt and name == "" or name == nil then exit
    * If no_prompt and name has content, send the request
  - By default, use the built-in "Substitute" and "Dimmed" highlight groups. Create "Dimmed" if it doesn't exist.
    * hl_new and hl_ghost should be provided as opts
  - opt to show preview before references come in (default true)
    * Would be substitute hl only based on cword
- Implementation
  * All communication with the LSP servers must use only the spec
  - Other than configuration, data must not be persisted between renames
  - prepareRename must be supported for servers that have it
    * If no_prompt and name, then just send it
    * Otherwise, do not open the prompt without running prepareRename
  - The original cursor position should be saved so that the request doesn't get stale when doing async
  - Only do the async implementation
  - Create our own namespace to avoid Neovim's defaults on this one
  - Use the VSCode multi-server selections strategy
    * If no rename providers at all, notify the user

#### NON-GOALS

- sync renaming
  * Maybe do this in the future if a use case comes up
- Callbacks for customizing behavior
  * This idea I actually like but it's inherently convoluted and I'd want to know the use case before exposing stuff
- Persistent config
  * Customization is spare enough that you can just pass opts into the Lua cmd, so you can just map what you want on Filetype
- Bespoke multi-server selection
  * You could have a preference opts list, but that's annoying to implement, and raises questions about why there aren't built-ins. Want to avoid the whole topic.

#### RESEARCH

- What are the technical details of how Neovim and inc-rename do what they do? What can we learn from them?

#### LEARNINGS

- For the rename result, I think we just want to use Neovim's built-in apply_text_edits function. We can try to get as deep as possible without going through every layer of validation, but at some point the logic is too complex. And it does all of the relevant handling or whatever.
- prepareRename handling:
  * null - Can't rename
  * Range only - Use that as your default
  * Range + placeholder - Use placeholder as default prompt
  * DefaultBehavior - Use cword

- VSCode references handling:
  * de-dupe
  * sort by file and position

https://github.com/smjonas/inc-rename.nvim/blob/main/lua/inc_rename/init.lua
https://github.com/nvimdev/lspsaga.nvim/blob/main/lua/lspsaga/rename/init.lua

#### TESTING/PLANNING

- Highlighting
  * You can build like, press a keymap and do highlighting + ghost text on cword without it actually doing anything. We want to have a working implementation of that so we know what the pitfalls are
  * We also want to see if virt text for adding spaces is viable
- Reference processing
  * Build out the reference processing pipeline independently
  * We need to time it then on bigger projects to see how long it takes. If it's too much, might need to do it with a coroutine
- Server scoring
  * This is a process basically independent of anything else
  * Should be in its own util file
- Rename/prepare renaming
  * We can just build a working re-implementation of rename that handles prepareRename the way I want it to be.

#### EVENT HANDLERS

- Create autocmds
  * I think you just always do this with clear autocmds
  * Watch the cmdline for changes and report them
  * Tear down events and state on leave
- Handle references coming in
  * Do necessary filtering and cleansing
  * Write them to some sort of state table
  * Push the refs to extmarks

#### Events

- On invocation
  * Setup the autocmds to track the cmdline contents
  * If a new name was provided, feed it to the cmd line
  * Request references from the server
- On references coming in
  *
- When the cmdline is left, those cmds need to be torn down

What data do you get if you try to run this on MD oxide? Both rename and references are per file which is weird.

what do you do if you don't have a client that supports references
print a message if no clients even support rename
