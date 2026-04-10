## General

#### LOW:

- [ ] Farm this: https://github.com/chrisgrieser/nvim-various-textobjs
- [ ] Are there action items or notes to take on this? https://github.com/neovim/neovim/pull/36261
  * Possibly related: https://github.com/neovim/neovim/discussions/32540
  * It looks like tmux is the remaining case where it doesn't work. Lots of different things colliding here.

## Plugins

#### META:

- For plugins with grep functionality
  * Only support rg out of the box
  * Provide interfaces for other grepprgs to plugin

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

- [ ] Once I have a working example (probably farsight), need to see how config metatable performance functions in real use cases. Based on that, we can evaluate how the question of internal interfaces as lightweight versions of the public APIs should be handled
  - [ ] Realistically though, because of config resolution, it's probably going to just be using skip_validation

- [ ] All functionalities should use the set pc mark behavior described in meta

- [ ] For plugins, when I update in lazy, I see both the push to the feature branch and then the merge into the master branch. How do you setup plugin installs so this doesn't happen?
  * Alternatively, is there a better way to handle feature/master branch?
  * Needs to be fixed so I can update feature branches between machines without spamming users

- [ ] How do you block direct pushes to master?

- [ ] Problem: I want to have a unified, idiomatic interface for controlling where items open.
  - This would primarily be for the rancher list opening use case.
  - I still think it's correct to go to {count} winnr if provided
  - If no count is provided, and no opts or config are provided, switchbuf should be respected
    * [ ] I think I have this in the TODO for nvim-tools, but it needs a comma opt parser so that swb can be handled
    * [ ] What happens if swb is empty? Would need to look at the code, because this appears to be situational
      * My hope is that, if swb is empty, then it acts like a hypothetical "usecurrent" option. I would prefer not to have to graft an additional opt in order to do that
        + The usecase here would be [q]q navigation, which should use the current window if it's a valid destination
    * [ ] How is swb used throughout the code? I would like to create a generalized swb finder, but I'm not sure if that's possible. I know quickfix is a bespoke use case (only certain swb options are respected)
      * The correct answer is probably the typical one - Build composable pieces

- [ ] nvim-tools
- [ ] docgen
- [ ] farsight
- [ ] lampshade
  - [ ] Maybe use the full config module, maybe use g/b variables. Big thing is - the user should not have to re-write the entire autocmd scripting to customize it
- [ ] rancher
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

## Core

#### TODO:

- [ ] Anything I can contribute here? - https://github.com/neovim/neovim/milestone/48

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

## Exterior Plugins

#### Harpoon

###### PR:

- [ ] Replace vim.loop with vim.uv
- [ ] Obscure bug where, if harpoon initializes without a cwd, it enter errors
  - I'm not sure how to re-produce this
