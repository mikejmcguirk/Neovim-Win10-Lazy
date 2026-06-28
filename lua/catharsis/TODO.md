## GENERAL

#### OBJECTIVES:

#### TODO:

- [ ] Try to consolidate all of the ctx checking into common logic. Maybe pass an opts table?

- [ ] Plugin conversion checklist:
  - [ ] Change annotations to a plugin format
    - [ ] Remove "mjm" annotations
  - [ ] Move nvim-tools functions into a plugin-specific util module.
  - [ ] Verify nvim-tools isn't being required anywhere

- [ ] Archive lampshade
  - [ ] When catharsis is uploaded:
    - [ ] Push a commit with an archived message + update the README
    - [ ] Archive the repo

## DOCUMENT HIGHLIGHT

#### TODO:

- [ ] Come up with a name for this module (like lampshade)

#### MID:

- [ ] Scope highlights per buf and win
- [ ] Add bracket navigation for highlights
  - [ ] Should print a message if the navigation is invalid.
  - [ ] Should immediately fail, rather than queuing navigations

#### PR:

#### NON:

- Don't use CursorHold.
  - It's tied to UpdateTime, which varies per config.
  - CursorMoved is required to immediately remove stale highlights. Using CursorHold and CursorMoved together spams requests.

## LAMPSHADE

#### TODO:

- [ ] https://github.com/neovim/neovim/pull/38988
  - This PR changes the default code action command to be by position rather than by line
  - Lampshade needs to account for this
    * Could show a different color lamp based on whether or not the cursor is over the action on the line
    * Could also just only show a bulb when over a Code Action

## Rename

#### TODO:

- [ ] Come up with a good module name.

#### MID:

- [ ] Generalize the concept by taking buf and ext_pos as opts. Because this would be able to be used in scripting though, more robust guards around prepareRename and rename request state would need to be added.
- [ ] Once cmdline is turned into a normal buffer, it should be possible to pull the cursor position out of it so it can be shown as part of the preview (just do it as a block cursor). Problem here - since this would be a new feature, would need a has statement to separate it out from the old code. Given significance of change, might be hard.
- [ ] It would be better if this filtered folds, but that requires window scoping of the preview results.

#### MID-DEP:

- [ ] The module currently assumes that a valid rename target will always produce a range from CWORD or the LSP. I'm not ruling out that there's a niche use case where this is valid behavior, but I would rather address it based on a concrete example than in the abstract.

## PRS

- [ ] Add old_mode and new_mode to the vim.v.event annotation. vvars_extra.lua. Not auto-generated.
- [ ] Update the annotation for ev.data.method in LspNotify

## ISSUES

- [ ] Neovim should provide a way to distinguish between `null` and `nil` results. Currently they both just render as `result == nil`
