## General:

#### TODO:

- [ ] Change these keys over - https://github.com/neovim/neovim/commit/3a4a66017b74192caaf9af9af172bdc08e0c1608
- [ ] Do these, collectively, prompt anything?:
  - https://github.com/neovim/neovim/commit/446e794a9c8823040b8d41fc86a1bc3bb99508e7
  - https://github.com/neovim/neovim/commit/1ff1973269594254900fbce40fd35c3024d9ed3d
  - https://github.com/neovim/neovim/commit/eaea0c0f9da38613a6b8e7f13e0cf4263f7e22f3
- [ ] I am seeing what looks like a memory leak when editing markdown files for a prolonged period
  - Preliminary conclusions:
    - Does not appear to be related to markdown-oxide. Disabling it does not stop ram buildup
    - This issue does not happen when editing text files, which rules out a number of things
      - blink
      - my text tools code
    - This does not happen when editing with nvim --clean. Includes using treesitter
    - If I run vim.treesitter.stop() then keep editing, the issue still occurs
    - If I disable markdown in nvim-treesitter, the issue still occurs
    - Running with bullets and text-tools disabled seems to help by slowing down the amount of edits made
  - Do I create some kind of automated testing for this?
  - Better idea - Create a minimal init and start building it in pieces
    - Basic options first

For plugins, I am seeing lazy updates on both my update branches and on the master branch. Need to figure out how to set plugin installs so that only the relevant branch is shown. Matters because I need to be able to pass TODO between computers without spamming users with updates.
- As a matter of practice, for git, look at how to block direct pushes to master in the repo.

I need to make some kind of plugin meta design assumptions doc to handle things like fdo, or default rg only.

https://github.com/neovim/neovim/milestone/48

Back to config
Farsight: Don't do fdo in callbacks due to win_call context
- [ ] While this doesn't apply to all plugin actions, if we apply it to some then not others, it creates an inconsistency. So it's better to say, Nvim's internal fdo behavior is a product of a limitation on how Nvim keymaps are customized. In the plugin case, because the maps are fully customizable, we consistently don't respet that limitation.
Nvim-tools: create a generic is-fillline-visible function. Rancher might need it.
text-tools: Create a text object that selects the line excluding the bullet and/or text box
- Very obviously: vi-
- va- would then select the entire list level you are in, you could use a- to expand to outer nested lists and i- to inner nested lists.
- You could also expand on this with [-]- to navigate between lists/checkboxes in the current buffer
text-tools: Add the i_/a_ text objects to this plugin?
- If I make a text objects plugin, they can be migrated
I'm not sure if this is a text tools thing or some kind of nvim-surround wrapper (maybe both?), but a way to visual line select multiple lines (or block select) then apply nvim-surround to each line.
  * Alternatively, Make the multi-cursor map to make a cursor for each visual line more convenient

- annotator need to support TODO comments the way I have them written in MD files

- nvim tools buf open needs to contain the reasoning for the fdo setting
- See if any other foldcmds need to be in the datatype
- This would apply to farsight as well

- the nvim tools config meta merge should unwind if a bad value is provided (MID)
- the nvim tools config should come with a checkhealth template (TODO)
- document nvim tools config examples (DOCUMENT)

- fix ability of multiline moves in markdowns to break nested indentation

- nvim-tools needs a generalized wrapping add/wrapping sub function

- Finish rancher additions

- nvim-tools config should provide a "validate against" function where you can take a config and validate it against the built-in validators
  * the use case for this is, if you have an API function that lives in config, and you take in a user table, you can use the validators in config rather than having to build a bespoke validation script
  * I'm not precisely sure how you handle nil. If the validator allows nil that's obviously fine, but then, if you're doing an API config table, you don't want to re-validate the defaults, so you would only pass the new values to validate, and nils should be treated as acceptable. But it feels simple enough to account for the use case where you'd want to re-validate the whole config.
  * this also points to the idea that you want some way of re-caching configs so you don't have to constantly run this heavy logic
- related: nvim-tools should also provide a generalized config layering template. So when you run an API, you can say "this is the config I'm using", and the config will handle validation, then merging in config/buf config values
  * first merge in buf config with keep behavior, then config with keep behavior
- nvim-tools config needs a generalized way to report its health. You should be able to run `require("plugin").config:get_health()` and `require("plugin").buf_config:get_health()`

Should show in the template version of config that global should be its own table, so that way you don't need to pull the whole config structure to see its values
- Counterpoint - Is it not faster to just pull the reference once? Though, by pulling the sub-tables, you can skip layers of validation when getting them

Two ways to improve perf:
- Allow a "skip validation" opt to be passed for ephemeral configs. This would come with the warning that any behavior that happens if this option is used is unsupported
- When a buf config is added or modified, do a buf_config < global config table merge with "keep" behavior and cache the result, so it does not have to be re-built each time it is used.
  * Creates complexity surface area, particularly as pertains to nested non-config tables

Because validation is becoming more expensive, the "always run validation" question needs to be re-opened.

add a future note in nvim tools like, as nvim ads buf and project/workspace config, update config if that prompts anything

stuff that I think is supposed to be for annotator
- [ ] Is fzf-lua's deep_clone function useful?
- [ ] In the documentation for buf_options, show an example of using an autocmd to get project information and set an appropriate buf option
  - [ ] Look at https://github.com/tpope/vim-projectionist

- Mapping ts-to conditional to d
  * The basic point is, you will never map id/ad as diagnostic text objects
  * id/ad is the one thing that's actually possible, as you could get the diagnostic list and then create a selection
  * But is this actually useful? Is it worth the development time? It's not about the mockup, I can get Grok to spit that out fairly quickly. But different LSPs are going to have different returns, which will create different behaviors. Does every LSP spit out an end position properly? This would mean that you would be visually selecting a point. Do different LSPs have different quirks in how the end positions are rendered? Inconsistent behavior, leading to having to then make fixes around the edge cases.
  * Let us presume that this can be made to work perfectly. What is the use case? This is something I've literally never wanted to do in my life.

Got this error when going to the bottom of an md and pasting an image. Not sure where around the pasting this happened.
Got it again when like, you paste the image on not the last line, save, and then the last line is removed before saving
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

- [ ] Manually going to the end of the line after doing gf is annoying. The function needs to smart place the cursor when a new TODO item is added
- [ ] Re-implement dynamic documentHighlight
  - Reasoning: I use this enough that it would side-step some amount of manual input
  - [ ] Question: How does this marry with my grh map?
    - Perhaps use grh to toggle dynamic highlighting, then grH to manually show the highlight if one exists

#### MID:

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
- [ ] Fzf-Lua send to qflist should use rancher
  - [ ] If an empty list is available, it should be used
- [ ] https://github.com/neovim/neovim/commit/4d04d0123d2571391a00b87f7ee70f987fb7cedd
  - Can this be used to make colorscheme more performant?
- [ ] Implement the farsight table_new code here
  - [ ] Make it variable based on if `jit` is present so that this can be opened in non-JIT builds
- [ ] https://github.com/neovim/neovim/pull/37141
  - Does this create an issue with comma fillchars? If so, make a PR?
- [ ] Change any abbreviated option values to their full names
  * Abbreviated option names produce more false positives when grepping
  * [ ] Make some kind of code style doc to collect notes like these. I've gone to, away from, then back to abbreviated options but I can't remember why
- [ ] Replace write cmd to scratch buffer custom code
  * [ ] This thread contains ideas on how to re-direct cmd output to a buffer: https://github.com/neovim/neovim/issues/30376. Research and pick the best one
  * [ ] Implement the chosen idea
* [ ] "gx"able URLs in markdown are not underlined. How can this be fixed?
* [ ] For prose buffers (md and text), should the option sets and insert `<C-g>u` mappings be outlined into utils? The options I think are fine, since I don't see why they would be different, but I've never loved the insert maps to begin with, and since Markdown is more "syntaxy" I'm not sure they should be the same
- [ ] The jumplist should not inherit bufs from other sessions
  * Starting it fresh each time is acceptable
- [ ] The new float statusline would be useful to show win info/buf info
- [ ] In fs, get_file_perms could probably be a general file info view
  - [ ] File size
  - [ ] mtime
  - [ ] Created
- [ ] @nomarkdown is considered two separate words for markdown line wrapping

#### LOW:

- [ ] Farm this: https://github.com/chrisgrieser/nvim-various-textobjs
- [ ] In-process LSP that pushes diagnostics for lines over a certain length. Could expand this into other general linting tools. Perhaps then move into a compiled language
  * Could also include fallback formatter
- [ ] How to do document exports. pandoc? 2html? Is there a plugin?
- [ ] Are there action items or notes to take on this? https://github.com/neovim/neovim/pull/36261
  * Possibly related: https://github.com/neovim/neovim/discussions/32540
  * It looks like tmux is the remaining case where it doesn't work. Lots of different things colliding here.
* [ ] What is secure mode and what does it do?

#### PR:

- [ ] https://github.com/neovim/neovim/issues/36081
  - Use rancher code here? What about a callback?
  - Possibly related: https://github.com/neovim/neovim/issues/37030
    * These both feel conceptually related
- [ ] Doc updates:
  - getchar andd getcharstr opts are not documented
  - getqflist and getloclist returns are any
  - nvim_win_get_config in the doc isn't tied to the _ret type. Maybe intentional
  - matchstrpos return type
  - setcmdpos
  - setcursorcharpos
  - wordcount
  - The opts type for vim.keymap.set does not show in the docs
- [ ] ts-text-object move should be able to distinguish between move selection and grow selection in visual mode
- [ ] ts-text-object select should place the cursor at the end closest to the cursor's location when the selection was initiated
- [ ] Can the built-in diagnostic stl element be used for my statusline?
  - [ ] Needs caching
  - [ ] Would need to be able to handle alt-window diagnostics
    - Might be related to caching
  - [ ] What else?

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

#### MID:

* [ ] grA
  * Whole buffer scoped code actions?

#### PR:

- [ ] Add an opt to the built-in rename function for filling in the current name
  - [ ] Reasoning: It should be possible to rename from a blank prompt without forgoing the use of prepareRename

## Maps:

#### TODO:

- [ ] Use [<C-t> and ]<C-t> for tabmove
  - [ ] Should this take a wrapping count?
    - Unlike qf-navigation, where you can go back, a mis-handled tab move creates a confusing arrangement of tabs. Might be better to just clamp at ends
    - [ ] If not wrapping count, use +/- args

#### FUTURE:

- [ ] Should ]t be gT or tabnext?
  - [ ] It's arbitrary for gT to be count back, whereas gt is absolute count
    - [ ] The defaults, though, are this way
  - [ ] Would sync with [Q]Q, where count on either is absolute count
    - [ ] On the other hand, This is also not capital
  - [ ] Alternative: Make both [t and ]t wrap, then use [T]T for absolutes. Would sync with qf

#### MAYBE:

- Use a harpoon-style buffer to edit tabpages

## Plugins

#### MID:

- [ ] Archived, but an nvim matchparen implementation - https://github.com/utilyre/sentiment.nvim

#### LOW:

* [ ] mini.splitjoin instead of treesj?

## LSP Feature Config Refactoring

Issues and PRs related to how to update and standardize LSP configuration.
