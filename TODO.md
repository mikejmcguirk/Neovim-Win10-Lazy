## General:

#### TODO:

- [ ] Double Hash issue in md file with top codelens

#### MID:

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

## ui2

#### TODO:

- If I do `imap <C-u>` it opens the pager (I think) with the result on multiple lines. I hit `<C-c>` once and it minimizes the pager, but then I need to hit `<C-c>` again to clear the line
  - [ ] There should be a way to make closing the pager and clearing the cmdline the same cmd

#### MID:

- [ ] If I `g<` into a pager window then leave or quit, it should go back to the previously used window
  * [ ] Check first if this is a settings issue. Maybe it's a problem if I have useopen before uselast
  * [ ] If it's not a settings issue, then, why wouldn't it work? Hate to open an issue without at least a suggestion on what to do. It feels like this would be the kind of thing that's a somewhat obscure bug.

#### MAYBE:

* [ ] Submit an issue for pager buffers being modifiable
  * I can't imagine that (a) this is intended behavior and (b) no one has noticed this. My guess is that, since nomodifiable buffers can't even be written to programmatically, this is currently allowed so it doesn't become a development chokepoint

## LSP Feature Config Refactoring

Issues and PRs related to how to update and standardize LSP configuration.

- https://github.com/neovim/neovim/pull/38344
- https://github.com/neovim/neovim/commit/e406c4efd6209e093d2d2caff7e3c9a0847ee030
