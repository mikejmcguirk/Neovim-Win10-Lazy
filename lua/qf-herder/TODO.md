## TODO:

- [ ] ftplugin
  - [ ] do not build bespoke code here where it can be avoided. `o`/`O` nav should be based on the nav module. Stack changes should be built on the stack module. And so on.
  - [ ] Each functionality should be connected to a public API surface that the user can remap. I would probably stick the split navigation into the nav module
  - One aspect of the original code's design, which created a lot of the differences, was that count there was used for destination window selection, which we are forgoing, so that causes a re-think of other aspects of how this is constructed
- [ ] filter
  - [ ] cfg data
  - [ ] apis
  - [ ] keymaps
- [ ] diags
  - [ ] cfg data
  - [ ] apis
  - [ ] keymaps
- [ ] grep
  - [ ] cfg data
  - [ ] apis
  - [ ] keymaps
- [ ] nav
  - [ ] keymaps

- [ ] Once all APIs and keymaps are up, disable old rancher so these can be used.

- [ ] The stack location list cmds should actually tell you if there is no location list.

- [ ] Add a `global` config table with opts like `spk` in it that merges under the module specific configs
- [ ] Rename lingering mentions of `ctx` to `cfg`
- [ ] Add cmds for sort, diags, grep, and filter.
  - [ ] Wait for all four to be done because we need a general parsing shape that accommodates all four rather than hacking stuff together like the old code did
  - [ ] User-defined commands should not be able to override or remove the built-ins

- [ ] Make relevant cmds take `cargs.smods.silent`
- [ ] Double check that all cmds that feed functions that use count1 clamp their values

- [ ] Do a project-wide variable ordering consistency check

- [ ] Change all mentions of "herder" back to rancher.

#### DIAGNOSTICS:

- [ ] have qin/qiw and so on for general diagnostics by/only severity
- [ ] have grq and grQ for LSP diagnostics in all buffers or current buffer (loclist)
- [ ] I'm not sure if this is in diagnostic opts or what, but make sure that there's a way for the user to customize namespaces/diagnostic sources in general

## DOC:

#### NAV:

- [ ] How the wrapping count works for p/nfile

## MID:

- [ ] Add cmds for the various modules:
  - [ ] Have a set of defaults that cannot be removed
  - [ ] Allow the user to register new args for each one
- [ ] Add preview win
  - [ ] Need to develop simple primitives for getting the position, even if they're a bit slower

#### WINDOW:

- [ ] Re-implement `cwindow`/`lwindow`
- [ ] Refactor bulk location win closing
  - [ ] Problem: Closing all location wins to open a qf list requires calling a helper function that sets spk, closes the windows, then resets spk. This means spk has to be set/unset twice to open a qf win. It also adds redundant code between open/toggle.
    - [ ] Possible solution: Just outline closing the windows and put it under the same spk set as the win open
      - [ ] Problem: This would spread window close spk logic into multiple places.

## TODO-DEP:

#### WINDOW:

- [ ] Make specifig `cfg` defs for the exposed functions as needed.

## MID:

#### WINDOW:

- [ ] Make resizing work off of bulk operations like everything else does.

## LOW:

#### NAV:

  - [ ] Support tab context for quickfix list navigation
  - If a quickfix list is open in another tab, `:cc` can be called in that list's window context to open the result in that list's tabpage.
  - For Rancher's custom navigation, tab context can also be used to get the cursor position from the quickfix window in a particular tabpage rather than the current one.
  - Problem: If the list is closed but you still want to run `:cc` in tab context, there is no tab_call or tab_execute function.
    * You could win_call from an arbitrary window, but it feels wrong to set window context to a window that is not actually the focus of the operation
    * You could create a temporary window, this feature does not add enough value to introduce that level of state management

* [ ] Custom window choice logic
  * An issue with bracket navigation is that it does not necessarily open in the current window
  * A problem here is that, AFAICT, the Quickfix navigation logic looks for windows where the target buf is already open. I don't think you can affect this using switchbuf
  * This would require creating bespoke logic, which, aside from the complication cost, goes back to the problems with opening help buffers

#### WINDOW:

- [ ] The old code had a "use_alt_win" option that entered the alternate window after closing the list window. This is not default behavior.
  - Problem: This creates a new set of WinEnter/WinLeave events.
    * Possible solution: Enter the alt win before closing. But, this breaks implicit assumptions
about the order of operations. Might leave the cursor in the new win on failure, unless it's specifically unwound.
    * Possible solution: Use eventignore. Creates problems on failure though.
  - This does not feel like a high-value enough feature to justify the complexity.

#### STACK:

  - [ ] The wrapup step could run bulk operations in case there are multiple list wins open. Obscure case though.
