## TODO:

- [ ] Do a project-wide variable ordering consistency check
  - [ ] src_win always first
  - [ ] cfg always last
  - [ ] Unsure
    - [ ] count
    - [ ] silent
    - [ ] ctx

- [ ] Should be a "goto_list_nr" _util func that does the stack change and window open

- [ ] Disable the old rancher so this can be used.
- [ ] Change all mentions of "herder" back to rancher.

#### PREVIEW:

- [ ] Is the existence of other preview wins + closing the preview win outside of rancher's APIs properly accounted for?

## MID:

- [ ] For modules like diagnostics and grep, the user should be able to configure a custom `what` table as an opt, so they can use a custom qftf or whatever else. Would need to be careful about what is allowed in though, as we don't want values like nr getting corrupted.
- [ ] Add cmds for sort, diags, grep, and filter.
  - [ ] Needs a general parsing shape
  - [ ] User-defined commands should not be able to override or remove the built-ins
#### Config:

- [ ] Add a `global` config table with opts like `spk` in it that merges under the module specific configs
- [ ] Case should have a "vim" mode that checks smartcase and ignorecase

#### DIAGS:

- [ ] It should be possible to configure the default sort
- [ ] have grq and grQ for LSP diagnostics in all buffers or current buffer (loclist)

#### GREP:

- [ ] Should count say what stack nr to put the results in?

#### WINDOW:

- [ ] Re-implement `cwindow`/`lwindow`
- [ ] Refactor bulk location win closing
  - [ ] Problem: Closing all location wins to open a qf list requires calling a helper function that sets spk, closes the windows, then resets spk. This means spk has to be set/unset twice to open a qf win. It also adds redundant code between open/toggle.
    - [ ] Possible solution: Just outline closing the windows and put it under the same spk set as the win open
      - [ ] Problem: This would spread window close spk logic into multiple places.
- [ ] Make resizing work off of bulk operations like everything else does.

## PR:

- [ ] win_config
  - [ ] border does not contain bold
  - [ ] Title datatype is any

## LOW:

#### GREP:

- For help grep, include the logic fzf-lua uses to check lazy.nvim unloaded plugins

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
