## TODO:

- [ ] More API buf changes - https://github.com/neovim/neovim/pull/38900
  - https://github.com/neovim/neovim/commit/d0af4cd9094f3439382622906da5b1c5cd82c294
  - https://github.com/neovim/neovim/commit/71ac4db335e00b03b27d2c4aa5ab90c083a3a3e7
- [ ] Change these keys over - https://github.com/neovim/neovim/commit/3a4a66017b74192caaf9af9af172bdc08e0c1608

## MID:

- [ ] https://github.com/modem-dev/hunk - Diff viewing is becoming more of a chokepoint. I don't know what tools you put together to do it, but it needs to be like, you make a new tab in Nvim, and you have the list of changed files in the quickfix list, and when you open a file it opens a diff view, and if you use quickfix bracket navigation it keeps both windows updated.
- [ ] https://github.com/sindrets/diffview.nvim
- [ ] The blink.cmp dictionary removed the plenary dep. Try installing again and see if the hung fzf issue still appears
  - https://github.com/neovim/neovim/issues/39552 - This pertains to an issue with job killing in vim.system, which seems relevant to the problem case that cause me to leave the dictionary completion source to begin with. Need to understand if this issue affects me there.
    * Most likely, I'll just need to try it with system monitor on. But still a good awareness item
- [ ] Treesitter memory leak:
  - Can make it happen with my tests/minimal init
  - Related? - https://github.com/neovim/neovim/issues/14216
  - More cumbersome, but can make happen in Lua
  - Does not happen in text
- [ ] https://github.com/MeanderingProgrammer/render-markdown.nvim - Render markdown in Neovim
- [ ] There is suddenly more impetuous to get out of LazyDev because it suppresses invalid require errors. This is normally not the worst but if you do it in an async context the error is never propagated.
- [ ] https://github.com/neovim/neovim/commit/bf917a503a38a4af9072f4473b340720d1d45851 - New built-in directory navigator/editor. Could this replace Oil?
- [ ] Send to quickfix in fzflua should work even if the result only has one item
* [ ] `[<C-t>` and `]<C-t>` to move windows between tabs
- [ ] Use `[<M-t>` and `]<M-t>` for tabmove
  - [ ] Should this take a wrapping count?
    - Unlike qf-navigation, where you can go back, a mis-handled tab move creates a confusing arrangement of tabs. Might be better to just clamp at ends
    - [ ] If not wrapping count, use +/- args
- [ ] Don't have a way to say, be in a buffer, see what made a change, then get the full git diff of that commit. I can use gitsigns blame to see the last change. Or I can use fzf-lua to pull old versions, but I can't get the diffs or like pull up the full old list of changes.
  - The use case here was, I knew in vim.iter() there was the change that added variadic generics, but I wasn't sure where the meta file was that had the Lua_Ls prototypes, so I wanted to use the commit info from iter.lua to get the list of changed files to see where the meta file was, and I just didn't have the stuff to get there.
- [ ] Needs to be some kind of Fugitive shortcut for "amend the last commit to advance it to the current state." Saves time/commits/pushes on cases where you need to fix a goof in the previous commit.
- [ ] https://github.com/wellle/targets.vim
  - Looks like it can solve the i| a| problem
  - Also an interesting thing where you can do di, and da, in text
  - Also this: https://github.com/kana/vim-textobj-user
  - Note in both of these, there are other ideas and some suggested mappings for them that are interesting
- [ ] Try to make dynamic rnu again
  - Blockers:
    - [ ] My file opening is in flux, so I don't want to chase a moving target
    - [ ] For the open file methods I use, I need to understand when the different parts of the process happen, so I know what I'm missing that's causing the flaky rnu appearance
  - Requirements:
    * [ ] Cannot require layering a bunch of hacks on top of each other that create complexity surface area.
    * [ ] Must be centralized. Cannot require setting nu/rnu in every problem filetype
- [ ] The jumplist should not inherit bufs from other sessions
  * Starting it fresh each time is acceptable
- [ ] Is the new `scrolloffpad` option useful for my use case?
- [ ] https://github.com/neovim/neovim/commit/7fff439395215001ab74a96cc3df3d1b6d795177 - Does this make Nvim's built-in completion featureful enough to replace nvim-cmp?
- [ ] Archived, but an nvim matchparen implementation - https://github.com/utilyre/sentiment.nvim
  - Do I just rewrite the core matchparen in Lua then expand upon it for my own purposes? The matchup.vim plugin creates issues
- [ ] https://github.com/ergodice/statuscol-oil.nvim

## LOW:

- [ ] https://github.com/previm/previm - Another markdown previewer
- [ ] Speeddating is a set of maps that it intuitively feels like Neovim should have, but I never use them and find them finnicky when I try. Either actually sit with them and try to learn them or re-develop them.
- [ ] Add a way for harpoon to handle multiple lists. It is becoming obnoxious to re-build the lists for the various sub-projects in here.
  - [ ] Use `<leader>a[` and `<leader>a]` to cycle lists.
  - [ ] And `<leader>a` something to bring up a list of lists.
  - The benefit of Harpoon of course is the inherent constraint it creates. You would need:
    * Sorting by oldest so you can see which ones are unused
    * Pinning for ones that you really don't want to go away
  - Harpoon is one of the only things I have that isn't a picker, the quickfix list, or some kind of bracket navigation. It takes up significant screen real estate and non-trivial keyboard real estate. "Directory local file bookmarks" is an idiomatic concept in Vim space.
    * Some kind of frecency-based thing is fine if it only writes on exit.
    * Some form of manual file bookmarks seems inherently valuable
      + But maintaining them is cognitive load
    * Because of restart > restore session, the need to have the immediacy of `<leader>{num}` to access files is reduced. You can argue that the harpoon bookmarks create a rail because a subset of files are so low fiction.
    * The original idea though might be the way, in that you define "sub-projects" within a directory that are expected to be stable.
    * IMO though this is not worth thinking about further without understanding emacs bookmarks and other solutions.
+ [ ] Grep the current visual selection in fzflua
- [ ] With stal = 0, ls = 0, disabling ts context, tmux commands, and window padding, you can make your own zen at home. Question - do you still just do it as a float or do you save the old window layout?
  - Unmerged winpadding PR: https://github.com/neovim/neovim/pull/37939
- [ ] For the intro scratch buffer, IMO it should either be set to be a noma scratch buffer or I should come up with a way that you can edit it and save it conveniently.
  - [ ] Caveat, I tried the scratch buffer thing before and there was some reason I ditched it, so I wouldn't just get rid of the current code until the new method has sat for a while.
- [ ] % on quotation marks does not go to the matching quote
- [ ] https://github.com/ribru17/ts_query_ls (and download build that disables built-in linter)
- [ ] Replace write cmd to scratch buffer custom code
  * [ ] This thread contains ideas on how to re-direct cmd output to a buffer: https://github.com/neovim/neovim/issues/30376. Research and pick the best one
  * [ ] Implement the chosen idea
* [ ] "gx"able URLs in markdown are not underlined. How can this be fixed?
- [ ] The new float statusline would be useful to show win info/buf info
- [ ] @nomarkdown is considered two separate words for markdown line wrapping. Why?
- [ ] https://github.com/neovim/nvim-lspconfig/commit/d50c6d53a40d5592b66a7ce989e0644fee51eeaa - Docs for how to add LSPConfig type annotations
- [ ] How do you jump to unsaved changes?
- [ ] https://github.com/karnull/only-tmux.nvim
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
- [ ] The visual move map, in markdown, can break nested indentation
  - Perhaps you only get the indentation of the first line, then adjust everything else based on that
  - [ ] More big picture, using equalprg for indentation is bad because it blows up dot repeat. There is probably an opportunity here to exercise the nvim-tools indent function
  - [ ] Perhaps it is time to move on from using the :move command completely. This can 100% be done using the API
    - One immediate question though is how to handle extmarks. I wonder if :move also moves them, in which case we would need a way to do that.
- I currently have Harpoon configured to display filenames only in the tabline. If duplicate filenames are found, it should display relative paths.
  * Doesn't it already handle this though?
* [ ] mini.splitjoin instead of treesj?
- If I do `imap <C-u>` it opens the pager (I think) with the result on multiple lines. I hit `<C-c>` once and it minimizes the pager, but then I need to hit `<C-c>` again to clear the line
  - [ ] There should be a way to make closing the pager and clearing the cmdline the same cmd
- [ ] If I `g<` into a pager window then leave or quit, it should go back to the previously used window
  * [ ] Check first if this is a settings issue. Maybe it's a problem if I have useopen before uselast
  * [ ] If it's not a settings issue, then, why wouldn't it work? Hate to open an issue without at least a suggestion on what to do. It feels like this would be the kind of thing that's a somewhat obscure bug.
* [ ] Why does hitting enter with a pager window open cause me to go into the pager. I think this is intended behavior, but I'd rather overwrite it. Should only be g< to enter
* [ ] Submit an issue for pager buffers being modifiable
  * I can't imagine that (a) this is intended behavior and (b) no one has noticed this. My guess is that, since nomodifiable buffers can't even be written to programmatically, this is currently allowed so it doesn't become a development chokepoint
- [ ] grA
  - Whole buffer scoped code actions?
