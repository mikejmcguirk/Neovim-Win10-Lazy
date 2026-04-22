## General

#### LOW:

- [ ] Farm this: https://github.com/chrisgrieser/nvim-various-textobjs
- [ ] Are there action items or notes to take on this? https://github.com/neovim/neovim/pull/36261 (PR on cursor style adjustment fixes)
  * Possibly related: https://github.com/neovim/neovim/discussions/32540
  * It looks like tmux is the remaining case where it doesn't work. Lots of different things colliding here.

## Plugins

#### META:

- For plugins that grep:
  * Only support rg out of the box
  * Provide interfaces for other grepprgs/plugins
    + fzf-lua
    + telescope
    + snacks
    + Future grep plugin

- In any case where it's logical for an option to control plugin behavior, it should do so, at least by default
  * The function's opts table should also provide a method for overriding the default option
    * The method should be appropriate based on the option
      + For fdo, a simple boolean can be provided
      + If overriding swb, an alternative option value would need to be provided

- Plug maps should fall into two categories:
  * "Main" Plug maps
    + These represent the default and most prominently advertised behavior of the plugin
    + Main Plug maps should never contain opts that override config. Because any API should check against config, default behavior should therefore be set in config
    + Because config and the APIs should already be documented, Plug documentation should only need to be minimal
      + Counterpoint: It should be possible for the user to understand the fundamentals of what the Plug does without having to look in other places
  * "Alt" Plug maps
    + These provide some kind of desirable, but non-default behavior out of the box
    + These mappings can override config
    + The differences from the defaults should be documented

- When designing interfaces, Neovim's patterns should be respected, its limitations not so much
  * Example: When Neovim's internal functions are used in mappings, fdo is ignored. This is so users can implement their own behavior
    + The more principled solution would be for respect_fdo or something like that to be a maparg
    + I had previously tried to implement this behavior by putting fdo handling into the default on_jump callback function. This was a bad idea
    + While jump behavior should use the fdo option (or a user-override), it adds friction to pocket it within the callback

+ Set pcmark behaviors:
  + Never set pcmark
  + Set pcmark if we go past w0 or w$
  + Set pcmark if we change lines
  + Always set pcmark

#### TODO:

- [ ] Figure out how to install plugins in lazy without seeing every push to feature branches
  - [ ] Alternatively, since it kinda looks like I'm going to be doing a full rewrite, perhaps just make a config-local version of rancher
    - On one hand, the lazy problem needs to be solved anyway. On the other hand, the process of re-writing rancher is going to be long and require a lot of writing docs, so I'm not sure I want to fill up the commit history with that kind of stuff

- [ ] Does this change how lampshade works? - https://github.com/neovim/neovim/pull/38988

- [ ] nvim-tools
  - [ ] All functionalities should use the set pc mark behavior described in meta

- [ ] docgen

- [ ] testing framework
  - Conversation in here about Nvim as Lua runner: https://github.com/neovim/neovim/pull/39116
  - New core testing framework: https://github.com/neovim/neovim/commit/55f9c2136e52d8719495b6021ce7e8d64c5141fe
    * https://github.com/neovim/neovim/pull/38486
  - The best outcome would be to publicly expose the core testing framework. If I were to do it:
    * As a PoC, I would need to create a plugin-based extraction of it
      + This could be helpful simply because, in doing this, I might come up with something simpler than working with the core testutils
      + Regardless of that, the goal would be to understand, in more detail, what the test framework does and how it needs to be accessed to be useful
    * Based on my findings with the extraction, I would need to create an exposed dev build locally to make sure I actually knew how to do it
    * Make an issue
    * Make a draft PR
  - This is after docgen, because making a public version of the test utils is an awareness item for the core devs. Not the case with docgen
  - lewis's test plugin still feels like a source of relevant info
  - needs to be plug and play. Can't be doing a bunch of config to make it work
  - needs to work in CI
  - Should, if at all possible, auto-create new nvim instances between tests so that doesn't need to be managed

- [ ] How do you block direct pushes to master?
- [ ] Is my fzf-lua-test file a good way to do a minimal init for plugin testing? Would want to look at what Neovim has (even after vim.pack) as well as fzf-lua's mini.sh script

- [ ] lampshade
  - The least exciting but also the simplest

- [ ] Once I have a working example (probably farsight), need to see how config metatable performance functions in real use cases. Based on that, we can evaluate how the question of internal interfaces as lightweight versions of the public APIs should be handled
  - [ ] Realistically though, because of config resolution, it's probably going to just be using skip_validation
    - You have to check config every time because it can change between calls
    - Because config is a table, you have to do a deep equal to see if they're the same (just using refs don't work because the underlying data could change. Getting around this issue would require extreme contrivance)
    - The deep equal is slow enough that you're not actually gaining any speed relative to just doing config merging
    - The one thing that could be viable is pre-merging buf config on write, which is complicated but might provide non-trivial perf gains, plus it is conceptually tractable
    - All of this needs to be documented because keeping the moving parts straight is non-trivially challenging

- [ ] Rancher vs. farsight first is a somewhat legitimate question:
  - My half-baked local version of farsight basically works
  - Rancher addresses a broader suite of things, so I'll be able to learn more from it, in terms of improving nvim-tools, seeing test cases for docgen, and so on
  - Because the individual pieces of rancher are smaller, it's a bit of an easier project to tackle
  - It is the project that is actually released and exists, so letting it languish in a liminal state feels wrong

- [ ] farsight
  - [ ] Maybe use the full config module, maybe use g/b variables. Big thing is - the user should not have to re-write the entire autocmd scripting to customize it

- [ ] rancher
  - [ ] qf positions are one indexed, end exclusive (see lhelpgrep results). The preview and diagnostic conversion code needs to account for this (same with grep perhaps)
  - [ ] I am concerned about the level of bespoke logic used for list opening. Can we not just build wrapper code around cc? Can it not just be nvim_win_call?
    - Obvious problem comes about when thinking about zzze.
    - I'm not sure if cc/ll auto-focus the opened window
    - Can look at how other plugins do it
  - [ ] Use updated qf_to_vex function for positions
  - [ ] https://github.com/ten3roberts/qf.nvim
    - [ ] Farm + Add to credits/references
  - [ ] The fallback preview buf has bufhidden set to wipe even though it's meant to persist. Should be hidden
  - [ ] I might have this noted already, but for cmd customization, store customized cmds in a separate table from the built-ins
  - [ ] Why is rging helptags slower than lhelpgrep? Aren't they both external grep?
    - [ ] My grep probably needs to take up unloaded lazy help files

  - [ ] Some kind of "grep dir" function that doesn't require setting cwd

  - [ ] When making new lists, there should be an attempt to re-use blank lists
  - [ ] Add an fzf-lua integration for sendtoqflist
    - Can be either a doc snippet or actual Lua code
    - [ ] Should be based on a re-usable title if possible

  - With rg only
    - Would keep the system module very general/flexible so it can accept a variety of external plugins

  - [ ] Instead of the current config for spk in the window functions, provide it as an option override and set the default config to topline as per the meta doc for plugs above
  - [ ] Tons of different bug issues and API fixes/updates
  - [ ] Address the grep API issues found when creating that integration
    - [ ] It is neither intuitive nor explained why there is a what table param
      - Presumably, this is to be able to do things like enter a qftext func
      - It is not explained if any what values are mandatory
      - [ ] The user should be able to pass nil or an empty table to get default behavior
    - [ ] It should be possible to pass a string argument for locations
      - Or, if it would be better to keep it as a pure function arg, the defaults need to be documented
    - [ ] Fzf-lua's approach of having "pattern" and "regex" be separate inputs is superior to having a regex flag. More intuitive
      - Because you don't have to cross-reference two things in your head
    - [ ] The "QfrSystemOpts" link in the Grep documentation is incorrect.
    - [ ] The system sort arg should be able to take a string arg
      - Alternatively, the defaults should be listed
    - [ ] In sync, "syncrhonously" is a typo.
    - [ ] List default behaviors/options for SystemOpts and GrepOpts
    - [ ] SystemOpts and GrepOpts should be able to take nil values
    - [ ] Print additional information on error to msgs
      - [ ] Grep cmd (truncated if it's too long)

  - [ ] In system, add an on_list callback. This might be useful for editing the result type in helpgrep to `\1` in a less arbitrary way
  - [ ] Add a "bcd" grep. For now, this can pull based on bufname and notify the user if that's not available
    - Necessary for being able to grep sub-folders without noise from the larger project

- [ ] grep plugin
  - [ ] Notes here are currently in the rancher docs. Outline back to my files

- [ ] Make a more useful rancher + grep plugin integration
- [ ] annotator
- [ ] text tools

#### LOW:

- [ ] In-process LSP that pushes diagnostics for lines over a certain length. Could expand this into other general linting tools. Perhaps then move into a compiled language
  * Could also include fallback formatter

#### FUTURE:

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
