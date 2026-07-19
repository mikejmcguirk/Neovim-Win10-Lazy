## MID:

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
