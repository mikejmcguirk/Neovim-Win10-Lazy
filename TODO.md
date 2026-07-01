## INTAKE

#### TODO:

- [ ] Make another attempt at using emmylua_ls by building from tip. The the generic handling issues in Lua_Ls are becoming a bigger problem.

#### MID:

- [ ] Investigate this: https://github.com/chrisgrieser/nvim-various-textobjs
  - [ ] Is this a plugin worth using? A plugin worth using as the basis for other things?
- [ ] Are there action items or notes to take on this? https://github.com/neovim/neovim/pull/36261 (PR on cursor style adjustment fixes)
  * Possibly related: https://github.com/neovim/neovim/discussions/32540
  * It looks like tmux is the remaining case where it doesn't work. Lots of different things colliding here.

#### SPEC:

## Plugins

#### TODO:

- [ ] All plugins + tooling should update to use the opts > ctx convention.

- [ ] "Dimmed" highlight group in `.13`: https://github.com/neovim/neovim/pull/39505
  - [ ] Plugins should check if it is already set (doesn't require `has()`) and link by default if so. Otherwise, link to comment
  - [ ] Don't define if it already exists. Not something we have ownership over
  - [ ] Add a deprecate tag - When `>=0.14` is out, just always use Dimmed
- [ ] Figure out how to push plugin updates to feature branches without every update showing up in lazy.nvim
- [ ] How do you block direct pushes to master?

- [ ] Plugin ordering
  - [ ] docgen
  - [ ] nvim-tools
  - [ ] catharsis (includes lampshade)
  - [ ] Grep plugin?
  - [ ] rancher
  - [ ] farsight

---------------

#### MID:

- [ ] Come up with a principled way to check for the truncated line in search plugins:
  - Use case: Jump plugins in wrapped buffers
  - Problems:
    * If you put jump tokens on a truncated line, you have to redraw with valid = false. This is slow
    * There is not a great way to find out if it is showing. You could look for the @ screenchar (or whatever the fillchar is), but this is a lot of logic
    * You could also see if the next line has a valid screenpos value, but this is slow and not totally reliable
    * Whether or not the line even shows depends on the user's display option
    * Also causes an issue where jumping into the line can force it to be scrolled to the middle of the window, so then do you also have to add a "norm! zb" call?

* https://github.com/neovim/neovim/commit/bbd0fdd36dcd684e09836ff41517e0e7ea6d802e - More efficient string parsing method

#### LOW:

- [ ] In-process LSP that pushes diagnostics for lines over a certain length. Could expand this into other general linting tools. Perhaps then move into a compiled language
  * Could also include fallback formatter

#### FUTURE:

- [ ] https://github.com/neovim/neovim/pull/38906 - Would be good to use this for plugin/docgen logging
- [ ] Based on experience, update the meta documentation for plug mappings

#### MAYBE:

- The plugin writing guidelines might benefit from being outlined into their own doc. Getting a bit too long for a meta section.

## Core

#### TODO:

- [ ] Anything I can contribute here? - https://github.com/neovim/neovim/milestone/48

#### MID:

- [ ] https://github.com/neovim/neovim/issues/39006
- [ ] https://github.com/neovim/neovim/pull/39054 - What does this mean?

#### PR:

- [ ] regex:match_line
  - [ ] Should be documented that start can be one past the end of the line
  - [ ] Stop should be clamped if it is past end of line plus one
  - [ ] If start > stop, should return nil/nil
    - This I'm less sure of because, while it's inconvenient for me to check, it would produce vague results from the function taken in isolation

- [ ] It should be possible to get the length of a line without allocating heap

- [ ] https://github.com/neovim/neovim/issues/36081
  - Use rancher code here? What about a callback?
  - Possibly related: https://github.com/neovim/neovim/issues/37030
    * These both feel conceptually related
- [ ] Doc updates:
  - [ ] getchar andd getcharstr opts are not documented
  - [ ] getqflist and getloclist returns are any
  - [ ] nvim_win_get_config in the doc isn't tied to the _ret type. Maybe intentional
  - [ ] matchstrpos return type
  - [ ] setcmdpos
  - [ ] setcursorcharpos
  - [ ] wordcount
  - [ ] The opts type for vim.keymap.set does not show in the docs
- [ ] ts-text-object move should be able to distinguish between move selection and grow selection in visual mode
- [ ] ts-text-object select should place the cursor at the end closest to the cursor's location when the selection was initiated
- [ ] Can the built-in diagnostic stl element be used for my statusline?
  - [ ] Needs caching
  - [ ] Would need to be able to handle alt-window diagnostics
    - Might be related to caching
  - [ ] What else?

- [ ] Add an opt to the built-in rename function for filling in the current name
  - [ ] Reasoning: It should be possible to rename from a blank prompt without forgoing the use of prepareRename

* [ ] Get SQLite into Neovim

## nvim-treesitter upstream

#### Tracking Issues

- https://github.com/neovim/neovim/issues/22313 : Master problem statement
- https://github.com/neovim/neovim/issues/39006 : Upstream nvim-treesitter work plan
- https://github.com/neovim/neovim/issues/39007 : Possible shipping of pre-built parsers
- https://github.com/neovim/neovim/issues/39037 : How to address installing non-shipped ts parsers
- https://github.com/neovim/neovim/issues/39008 : WASM parser support
- https://github.com/neovim/neovim/issues/39009 : Syntax detection/configuration
  * I have a comment in here

## Exterior Plugins

#### Harpoon

###### PR:

- [ ] Replace vim.loop with vim.uv
- [ ] Obscure bug where, if harpoon initializes without a cwd, it enter errors
  - I'm not sure how to re-produce this

## Stalking:

- https://github.com/ofseed/nvim
- https://github.com/tris203/.dotfiles/tree/main/nvim
