## TODO:

- [ ] Finish farsight (target: when v0.13 comes out)
- [ ] When we have plugins to push to Github:
  - [ ] Figure out how to push plugin updates to feature branches without every update showing up in lazy.nvim
  - [ ] How do you block direct pushes to master?

- [ ] nvim-tools needs to come out with this because it's a dep
- [ ] Use farsight as the model for rancher. (Data structures, ci, etc.)
- [ ] Same for farsight + rancher > catharsis
- [ ] Release plugin template based on learnings from all three

## TODO-DEP:

VERSION BASED CODE REMOVALS

- [ ] 0.14
  - [ ] nvim-tools bcd_get
  - [ ] nvim_create_autocmd: change buffer to buf
  - [ ] nvim-tools win_resize wrapper
  - [ ] Manual creating of the "Dimmed" highlight group in plugins
  - [ ] For any uses of nvim_win_call or nvim_buf_call with multiple returns, remove any table packing logic
  - [ ] Remove optional tables from API calls
- [ ] 0.15
  - [ ] nvim-tools nonnil wrapper

## MID:

- [ ] Handle non-version controlled files
  - [ ] General troubleshooting inits can stay
  - [ ] Other stuff should probably be deleted
- [ ] https://github.com/neovim/neovim/pull/40948 - Implement this as a map for Oil (`1-` to open cwd. Higher counts go upward)

- [ ] Turn annotator into a plugin.
- [ ] Turn text tools into a plugin.
  - [ ] This needs to have the list visual mode selections in order to be a sufficient value-add over vim-bullets
  - [ ] Should also have proper multicursor support

- [ ] Decide if there's enough meat on an operator plugin to spend time making one. If not, internalize the cursor'd yank code and figure out a more elegant solution for the gu mappings
  - [ ] Remote operation research:
    - [ ] Determine if this is too big an idea for Nvim
    - Flash remote
    - https://github.com/goldfeld/vim-seek
  * [ ] Swap motions ideas:
    * [ ] Normal: You do `)iw`, it sees if you are in an inner word, then finds the next inner word and swaps them. `(iw` would do the same but with the previous. This is basically like the treesitter text objects swap but extended to other text objects. (You could also implement lookahead to find the next inner word, then use that as the swap for the origin)
      * [ ] Use double count to define both how many rotations to perform and how many objects to rotate
        * [ ] `)2iw` means rotate the current and next two inner words
        - [ ] `2)2iw` means rotate those inner words twice. Position 1 moves to position 3, 2 to 1, and 3 to 2.
          - This means that `2)iw` would do nothing. There should be some kind of built-in hl_on display so that the user knows a swap happened, even if it has no actual outcome.

- [ ] Investigate this: https://github.com/chrisgrieser/nvim-various-textobjs
  - [ ] Is this a plugin worth using? A plugin worth using as the basis for other things?
- [ ] Are there action items or notes to take on this? https://github.com/neovim/neovim/pull/36261 (PR on cursor style adjustment fixes)
  * Possibly related: https://github.com/neovim/neovim/discussions/32540
  * It looks like tmux is the remaining case where it doesn't work. Lots of different things colliding here.
* [ ] https://github.com/neovim/neovim/commit/bbd0fdd36dcd684e09836ff41517e0e7ea6d802e - More efficient string parsing method

## LOW:

- [ ] https://github.com/neovim/neovim/pull/38906 - Use this for plugin logging.
- [ ] For plugin docgen, my understanding is there is an emmylua annotation that has the same functionality as `nodoc`. It would be better to use the built-in emmy annotation.

## PR

- [ ] ts-text-object move should be able to distinguish between move selection and grow selection in visual mode
- [ ] ts-text-object select should place the cursor at the end closest to the cursor's location when the selection was initiated
- [ ] Doc updates:
  - [ ] getchar andd getcharstr opts are not documented
  - [ ] getqflist and getloclist returns are any
  - [ ] nvim_win_get_config in the doc isn't tied to the _ret type. Maybe intentional
  - [ ] matchstrpos return type
  - [ ] setcmdpos
  - [ ] setcursorcharpos
  - [ ] wordcount
  - [ ] The opts type for vim.keymap.set does not show in the docs

## STALKING:

- https://github.com/ofseed/nvim
- https://github.com/ibhagwan/nvim-lua/tree/main
- https://github.com/tris203/.dotfiles/tree/main/nvim
