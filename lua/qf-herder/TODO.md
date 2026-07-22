## TODO:

- Why are we sending tabpage to quickfix cmds? I think it's only so we know scope for spk. I don't understand why that needs to be an input var.
  * Prioritize because this idea is upstream of so many interfaces
- `_util` is accumulating functions that are not orthogonal. Reduce to a set of functions that have mutually exclusive concerns.
  * Additionally, move to relevant modules. Window opening/closing should be in window
- Put stack functions into stack, because future dev will need them
- Add remaining stack cmds
* stack and sort maps
* stack and sort options
  + schema
  + defaults
  + partials
  + opts tables

- Change all mentions of "herder" back to rancher.

#### DIAGNOSTICS:

- have qin/qiw and so on for general diagnostics by/only severity
- have grq and grQ for LSP diagnostics in all buffers or current buffer (loclist)
- I'm not sure if this is in diagnostic opts or what, but make sure that there's a way for the user to customize namespaces/diagnostic sources in general

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

## LOW:

#### WINDOW:

- [ ] The old code had a "use_alt_win" option that entered the alternate window after closing the list window. This is not default behavior.
  - Problem: This creates a new set of WinEnter/WinLeave events.
    * Possible solution: Enter the alt win before closing. But, this breaks implicit assumptions
about the order of operations. Might leave the cursor in the new win on failure, unless it's specifically unwound.
    * Possible solution: Use eventignore. Creates problems on failure though.
  - This does not feel like a high-value enough feature to justify the complexity.

#### STACK:

  - [ ] The wrapup step could run bulk operations in case there are multiple list wins open. Obscure case though.
