## GENERAL

#### OBJECTIVES:

- [ ] Use the nvim-tools config module

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

#### SPEC:

- It might be useful to window-scope highlights.
  * Motivation:
    + If you have a buffer open in two windows, you can update the relevant document highlights in window a, and then when you return to window b the highlights for that cursor position are immediately available.
  * Problems:
    + If the buf version updates, you have to scan through every window-scoped result to check if it's relevant
    + Client requests do not come back with window ctx. For each buf key under requests, you would need to then store window-keyed requests. So when you get a request back from the server, you need to get its id, then iterate over pairs to find the buf request with that ID so you can extract the window information.

#### PR:

#### NON:

- Don't use CursorHold.
  - It's tied to UpdateTime, which varies per config.
  - CursorMoved is required to immediately remove stale highlights. Using CursorHold and CursorMoved together spams requests.

## DOCUMENT HL NAV

#### OBJECTIVES

- When a document highlight is showing, the user should be able to use bracket navigation to go to the previous/next highlight.

###### QUESTIONS

- If the user uses the bracket cmd and there is no document highlight present, what should happen? My instinct is that it should just show a "No highlights" message or a "Server does not support Document Highlight" message, because I don't see why it would be helpful for a user key press to inject itself into the module's event system.
  * The rough execution path would be something like - Check first to see if there is a highlight, if there is not one, then look at the reason why. There are a lot of reasons there might not be highlights and they have to be checked at runtime, so we want to avoid that path if we can. If the user wants to spam invalid requests, well, so it goes then.

#### DESIGN

###### RESEARCH

###### ARCHITECTING

- When the key is pressed, we need to know which of the cached highlights the cursor overlaps, so we can then iterate through the list
  * Dumbest solution - Do a binary search of the cached ranges against the cursor position
    + This is an ad hoc non-trivial time complexity solution
    + How does mfussennegger's overfly map do this?
    + Given that we have to check the cursor on CursorMoved anyway, is there not a way to save those results? get_ref_under_cursor does not identify which cached extmark we are overlapping, only that there is one.
      + This spooks me though because there could be goofy overlapping conditions involved.
      + Something to consider is that we check the cursor position for validity anyway when we generate the highlights, so you could use that cursor position as a starding point. We also do cache it anyway.
  * We need some kind of list tool where, given a particular list, start index, direction, and n items to move, you get the nth list item, wrapping around the list if necessary.
    + The simplest way to do this, probably, is to feed a list into the function, and then generate the args for wrapping add/wrapping sub.

###### PLANNING

###### TESTING

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

## PRS

- [ ] Add old_mode and new_mode to the vim.v.event annotation. vvars_extra.lua. Not auto-generated.
- [ ] Update the annotation for ev.data.method in LspNotify

## ISSUES

- [ ] Neovim should provide a way to distinguish between `null` and `nil` results. Currently they both just render as `result == nil`
