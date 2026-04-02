## General:

#### TODO:

- [ ] Why does entering a prose buffer blow up rnu?
  - The scenario that seems to create this is:
    - Have a non-prose buffer
    - Use fzf-lua to open a prose buffer in it
- [ ] When editing a markdown file for a prolonged period, what seems to be a memory leak occurs (I saw Nvim taking up over 200MB of RAM). Why is this?

#### MID:

- [ ] % on quotation marks does not go to the matching quote
- [ ] fs/git primitives for nvim_tools + system maps:
  * [ ] Blocker: Because of the amount of fs ops that go into some of these, callback hell becomes a non-trivial concern. Would need to learn co-routines or wait for vim.async
  * [ ] Git
    + [ ] Is file git tracked
    + [ ] Git delete
    + [ ] Git mv
  * [ ] fs
    + [ ] unlink
    + [ ] mv
    + [ ] mkdir
      + [ ] mkdir -p
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

#### LOW:

* [ ] mini.splitjoin instead of treesj?

## LSP Feature Config Refactoring

Issues and PRs related to how to update and standardize LSP configuration.

- https://github.com/neovim/neovim/pull/38344
- https://github.com/neovim/neovim/commit/e406c4efd6209e093d2d2caff7e3c9a0847ee030
