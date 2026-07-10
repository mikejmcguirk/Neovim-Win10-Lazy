## TODO:

- [ ] Investigate if it's possible to do a file rename command that handles file logic, LSP, and git in one shot. I'm not sure if Oil and/or Fugitive and/or Core already do this.

- [ ] In every module, removing "clearing" behavior and replace with niling/overwriting the relevant tables. This has a perf cost but is simpler to reason about.
  - [ ] rename
  - [ ] doc_hl
  - [ ] lampshade

- [ ] Fix any "HUGE_INT" values to actually be ints, and not floored infinity

#### Rename

- [ ] Come up with a name for this module (like lampshade)

#### Document Highlight

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
- [ ] Mode changes would be more performant if they did not destroy extmarks. I'm not sure how to implement this though in a way that is not complex and hacky, for a minimal perceived perf benefit.
- [ ] Both lampshade and document highlight query namespace extmarks to see if decor exists. Lampshade could alternatively hold the current extmark id, and document highlight could maintain a `has_decor` flag.
  - This creates the burden though of maintaining a parallel source of truth with Neovim's internal state

#### Lampshade:

- [ ] Getting code actions only based on cursor position can produce effects where the server does not produce code actions for diagnostics you are within because the diagnostic context is too big for the cursor position (can be seen in Lua if you create syntactical mistakes in large tables). This behavior does not seem to be incorrect or inconsistent with Neovim, but creates weird UX.
  - Fixing this though would be a lot of effort for something relatively low leverage
    * Fully re-implementing code action requests and creating integrations to send them to pickers
    * Trying to write a smart behavior for request ranges that is server agnostic
    * Managing the difference between the request range and the cursor position
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
