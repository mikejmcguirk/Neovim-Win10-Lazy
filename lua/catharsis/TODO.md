## TODO:

- [ ] Investigate if it's possible to do a file rename command that handles file logic, LSP, and git in one shot. I'm not sure if Oil and/or Fugitive and/or Core already do this.

- [ ] Does the on_win callback contain the ns? Is it simpler to set a current win flag in the module that it is to edit the namespace? We have a namespace check in doc_hl anyway
  - [ ] Related, in document highlight, we destroy and re-create the extmarks on mode-changed. Is it not possible to simply not render if the ns win doesn't match? There's already a check on that per win anyway, no? Though would this make on_win try to render every win for the namespace? Maybe a worthwhile tradeoff

- [ ] In every module, removing "clearing" behavior and replace with niling/overwriting the relevant tables. This has a perf cost but is simpler to reason about.
  - [ ] rename
  - [ ] doc_hl
  - [ ] lampshade

- [ ] For document highlight, go back to per client timers with win/cursor info. We want to allow requests to succeed that will be valid when returning to the window. Has to be a per-buffer aspect though since the scoring logic could provide different clients to each buffer.

#### Lampshade

- cursormoved/insertleave
  * check valid curwin
  * on insertleave, redraw if valid
  * request
- diagnosticchanged
  * no insert mode
  * check valid win/curwin
  * refresh if not none to none diags
- insertenter
  * clear ns
- notify clear
  * clear
- notify change
  * clear
  * request if curwin
- didopen
  * request if curwin

#### Rename

- [ ] Come up with a name for this module (like lampshade)

#### DOCUMENT HIGHLIGHT

- [ ] Come up with a name for this module (like lampshade)

## TODO-DEP:

- [ ] When it's time to publish
  - [ ] Fix typing in init module. Hopefully nvim-tools dev has already assisted with this
  - [ ] Clean up TODO docs and commentary to be less rambly
  - [ ] Change type annotations to a plugin format
    - [ ] Remove "mjm" annotations
  - [ ] Move nvim-tools functions into a plugin-specific util module.
  - [ ] Verify nvim-tools isn't being required anywhere
  - [ ] Archive lampshade
    - [ ] When catharsis is uploaded:
      - [ ] Push a commit with an archived message + update the README
      - [ ] Archive the repo

## MID:

- [ ] PR: Neovim should support:
  - [ ] An arbitrary `user_data` table field on the `vim.lsp.Client` class. This would allow users/plugins to attach data directly to it.
  - [ ] The `get_clients` function filter should have a `func` key that allows for a function that takes a `vim.lsp.Client` table as a param and returns a boolean.
  - Reasoning: This would save a lot of bespoke handling of valid client and buffer state.

- [ ] Try to make the timer model work such that the first request goes immediately, then sets a debounce before another one can go. Gets weird because the request handler needs to check the timer and active requests to see if it's stale.

#### Lampshade:

- [ ] Instead of buf_request all, either blast all clients or own the iteration. Both possibilities allow us to:
  - [ ] Own which clients we are requesting, allowing for per-client timers
  - [ ] More finely control when we early exist upon finding a result
  - [ ] Allow for client filtering in the _features module

## MID-DEP:

#### Rename:

- [ ] The module currently assumes that a valid rename target will always produce a range from CWORD or the LSP. I'm not ruling out that there's a niche use case where this is valid behavior, but I would rather address it based on a concrete example than in the abstract.

## LOW:

- [ ] In any case where data is niled, table clear unless the buffer data is being purposefully destroyed.
- [ ] Try to consolidate all of the ctx checking into common logic. Maybe pass an opts table?

#### Rename:

- [ ] Scope the results per window so folds can be filtered.
- [ ] Add more customization to highlighting

## NON-GOALS:

- Problem: If you change windows containing the same buffer, we re-query lamps and highlights from the server.
  * Solution: Store lamps and highlights per buffer and per window
  * Why this doesn't work:
    + Overly complex data management relative to the severity of the problem, both in terms of events and caching?
    + The LSP data model is per-buffer, which this works against
      + Related: lamp and highlight are the only capabilities this remotely makes sense for
    + If you store per window, what is the principled reason for not storing per cursor position, only clearing cached results when the buf version changes? Creates more stored data and complexity.

+ Using the `CursorHold` event
  - It's tied to UpdateTime, which varies per config.
  - CursorMoved is required to immediately remove stale highlights. Using CursorHold and CursorMoved together spams requests.

## PR:

- [ ] Add old_mode and new_mode to the vim.v.event annotation. vvars_extra.lua. Not auto-generated.
- [ ] Update the annotation for ev.data.method in LspNotify

## ISSUES:

- [ ] Neovim should provide a way to distinguish between `null` and `nil` request results. Currently they both just render as `result == nil`
