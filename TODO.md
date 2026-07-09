## OBJECTIVES:

- Align Neovim with my mental model of how it should work.

## CONSTRAINTS:

- This series of docs needs to live within the idea of reducing regret within Neovim as a tool, rather than addressing it as a piece of critical infrastructure.
  * Nothing here can spawn a "CRITICAL" TODO annotation
  * Any plugin change needs to be able to be backed out at any point. Can't be in an "it's too late, it's already begun" type situation
- Top and config level docs should not have nested headers. Over-complicated

## TRAVERSAL

- TODO > MID > LOW
- Plugin ordering
  - catharsis (includes lampshade)
  - farsight
  - Grep plugin?
  - rancher
  - nvim-tools
  - docgen

## TODO:

## TODO-DEP:

* If, after a week of using Emmylua_Ls, it actually works, remove LazyDev and begin the process of converting the repo over to it.
* If we can use EmmyLua_Ls for a week without issues:
  + Remove LazyDev
  + Convert repo to EmmyLua annotations
  + Fix EmmyLua diags
  + Emmylua_Ls loads stably at this commit: https://github.com/EmmyLuaLs/emmylua-analyzer-rust/commit/fbc11afde0e5dffcec0073af91273c6dce580f00
- [ ] When we have plugins to push to Github:
  - [ ] Figure out how to push plugin updates to feature branches without every update showing up in lazy.nvim
  - [ ] How do you block direct pushes to master?

## MID:

- [ ] https://github.com/neovim/neovim/issues/39006 - nvim-treesitter upstreaming/alternatives
  - https://github.com/neovim/neovim/issues/22313 : Master problem statement
  - https://github.com/neovim/neovim/issues/39006 : Upstream nvim-treesitter work plan
  - https://github.com/neovim/neovim/issues/39007 : Possible shipping of pre-built parsers
  - https://github.com/neovim/neovim/issues/39037 : How to address installing non-shipped ts parsers
  - https://github.com/neovim/neovim/issues/39008 : WASM parser support
  - https://github.com/neovim/neovim/issues/39009 : Syntax detection/configuration
    * I have a comment in here
- [ ] Investigate this: https://github.com/chrisgrieser/nvim-various-textobjs
  - [ ] Is this a plugin worth using? A plugin worth using as the basis for other things?
- [ ] Are there action items or notes to take on this? https://github.com/neovim/neovim/pull/36261 (PR on cursor style adjustment fixes)
  * Possibly related: https://github.com/neovim/neovim/discussions/32540
  * It looks like tmux is the remaining case where it doesn't work. Lots of different things colliding here.
* [ ] https://github.com/neovim/neovim/commit/bbd0fdd36dcd684e09836ff41517e0e7ea6d802e - More efficient string parsing method

## LOW:

- [ ] Come up with a principled way to check for the truncated line in search plugins:
  - Use case: Jump plugins in wrapped buffers
  - Problems:
    * If you put jump tokens on a truncated line, you have to redraw with valid = false. This is slow
    * There is not a great way to find out if it is showing. You could look for the @ screenchar (or whatever the fillchar is), but this is a lot of logic
    * You could also see if the next line has a valid screenpos value, but this is slow and not totally reliable
    * Whether or not the line even shows depends on the user's display option
    * Also causes an issue where jumping into the line can force it to be scrolled to the middle of the window, so then do you also have to add a "norm! zb" call?
- [ ] In-process LSP that pushes diagnostics for lines over a certain length. Could expand this into other general linting tools. Perhaps then move into a compiled language
  * Could also include fallback formatter
- [ ] https://github.com/neovim/neovim/pull/38906 - Would be good to use this for plugin/docgen logging

- [ ] Doc updates PRs:
  - [ ] getchar andd getcharstr opts are not documented
  - [ ] getqflist and getloclist returns are any
  - [ ] nvim_win_get_config in the doc isn't tied to the _ret type. Maybe intentional
  - [ ] matchstrpos return type
  - [ ] setcmdpos
  - [ ] setcursorcharpos
  - [ ] wordcount
  - [ ] The opts type for vim.keymap.set does not show in the docs

- [ ] PR: ts-text-object move should be able to distinguish between move selection and grow selection in visual mode
- [ ] PR: ts-text-object select should place the cursor at the end closest to the cursor's location when the selection was initiated
- [ ] PR: It should be possible to get the length of a line without allocating heap
* [ ] PR: Get SQLite into Neovim

- [ ] PR: Harpoon
  - [ ] Replace vim.loop with vim.uv
  - [ ] Obscure bug where, if harpoon initializes without a cwd, it enter errors
    - I'm not sure how to re-produce this

## STALKING:

- https://github.com/ofseed/nvim
- https://github.com/ibhagwan/nvim-lua/tree/main
- https://github.com/tris203/.dotfiles/tree/main/nvim
