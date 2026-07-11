It's been a while.

## OBJECTIVES:

- [ ] Support the following features:
  - [ ] Live Jumping:
    - [ ] Flash/lightspeed style jumping
    - [ ] Support the lightspeed feature where, if you have a unique key after the token, pressing the unique key goes there
  - [ ] Static Jumping:
    - [ ] EasyMotion/Jump2D style jumping
  - [ ] Csearch Plus:
    - [ ] This should support both classic searching as well as the enhanced f/t style
      - Primary motivation is so I can move live jumping to ;/, which frees the `s` key.

## CONSTRAINTS:

- We must cease our chase of the SoA white whale
- Since I have the tooling to do it, we should build everything around lists of ranges
- Use recursion where it makes sense. The label creator greatly suffered from the attempt to move to a queue-based design
- The broad-based goal here is to think in terms of algorithmic complexity and design wins that create leverage, not micro-opting. I just want this to be done and to work
- Don't try to make nvim-tools stuff here. Just make farsight work.
- The names are Live, Static, and Csearch. If something better pops into my head great, but I'm not brainstorming further.
- Don't bother doing anything with screen positioning. Too hard/slow

## TODO:

- [ ] First and foremost, we need to go back through the various files and re-ingest all of the TODO info. There is going to be info in there about challenges we've run across
- [ ] A review of the past code is also relevant. A lot of it won't matter because of the design change, but it's worth considering what challenges we run into
- [ ] From there, the first thing will be data structures and data flow

## DESIGN:

- [ ] The data flows, and how they all work together, need a lot of pre-attention, because being unable to manage this killed the previous version

- [ ] Need to figure out csearch traversal. Don't want to use bespoke UTF-8 if it can be avoided, but need correct by-char iteration.

- [ ] Something I goofed in the previous code - Dim should be applied to the searched area, not the target lines. This provides the user a visual indicator of where the search is happening

- [ ] Verify and note indexing for match_line or whatever.

- [ ] Fold handling
  - [ ] Static jumps should put a single label on folded lines. The current code does this
  - [ ] Live jumps should ignore folds
  - [ ] Csearch is weird because we don't want to draw extmarks for folds, but we need to account for them because of highlights relative to count. I forget how the current code handles this

- [ ] For multi-window search, when a buffer is present in multiple windows, we should compare top and bottom of each window to avoid re-searching data. Unsure if you chain lists then or what.
  - [ ] This means that the result ranges need to be original, un-modified tables. If we store the results by reference in different range collections, we can't modify one for labelling and affect the copies in other range tables.
  - [ ] It would also be directionally ~bad to just kind of let the references get spread around everywhere, as it makes things harder for gc

- [ ] General search module:
  - [ ] Needs a start position option:
    - Fwd Csearch needs to always start at the beginning of the line so we can gather `\k\+` results that start before the cursor and truncate them to just after the cursor
    - Fwd Static jumps need to always start one after the cursor
  - [ ] Integrated design for multi-window needs to be the starting assumption
    - [ ] For re-search avoidance, we need to hold top and bottom for each window
    - [ ] For result filtering, we need to hold the line cache
  - [ ] Search can only handle search, even if it returns rich data
    - We do not want to allocate a bunch of extra nonsense for Csearch, which only needs the ranges
  - [ ] Need to re-look at how match_line handles zero width results (`\ze` and others)
  - [ ] need to properly ignore patterns that end with a single `\`.
    - Relevant in all cases, since all three can take custom search patterns. Needs to return a relevant and specific error rather than just an empty result, so callers know not to even bother trying to handle
  - [ ] Results need to have a flag to indicate when "distance" ordering is reversed, for reversed csearches and live jumps.
  - [ ] Needs to be some method of handling the capitalization atoms in various situations
    - csearch and static need to be strictly cased
    - live needs to be optional

- [ ] Labeling:
  - [ ] Determine max possible labels based on tokens and capped factorial
    - [ ] Issue: Can't do this with byte length due to multi-byte cars. Maybe just only use ASCII for tokens?
    - [ ] Do a simple i iteration based on that, dividing out the pieces for fair labeling, including on live jumps, since we'd just take the ordered tokens. Recurse down
      - [ ] Only an issue on very small tokens or live jumps
  - [ ] Need the data structure to handle start and end labels. Relevant for omode/vmode static jumps or if the user sets the labeling to both

- [ ] Options design:
  - [ ] Tokens
    - [ ] Live and static should have their own tokens
    - [ ] Static should just use alphabetical order/fair labeling
    - [ ] Live should use preferred tokens. Home row/e should be first. I think I have a version of this sitting around.
    - [ ] Capital letters should just be added manually. I see no reason to do voodoo here
  - [ ] Label location
    - [ ] Live: Right after result only (so no option)
    - [ ] Static: start/end/start+end/cursor-aware

- [ ] Live search:
  - [ ] Do not allow `\` as a token because it blocks atoms

- [ ] Csearch:
  - [ ] Do not do continuation mode in omode or on dot-repeat
    - Omode you can just handle with a flag in the private module. Dot repeat you probably have to always turn off.
  - [ ] Need to be mindful of when the stuff under the cursor is and is not deleted when using these motions with operators
  - [ ] Note: For default f/t, ;/, always advance by one, ignoring count. Count is only for the initial movement
  - [ ] pcmark options:
    - [ ] never
    - [ ] on screen change (default)
    - [ ] always
  - [ ] Dot repeat
    - Very roughly, this needs to allow us to enter the last continuation mode, so it isn't just lost
    - Question: Does dot repeat advance by the same count as before? I forget how the default works, but

## TODO:

## PUBLISHING:

- [ ] Everything should use the "targets" and "target locator" branding
- [ ] Add `desc` values to Plug and default mappings
- [ ] Verify that the `require("farsight")` call in /plugin.lua does not require other files

## MID:

- [ ] For `nowrap` buffers, you can use `getwininfo()` to build the left and right bounds for line display, then filter out OOB results. Unlike with a lot of stuff dealing with screen positioning, this should be one or two data pulls from Neovim then the rest is Lua calculation.
- [ ] Implement a `csearch` option to always set the pcmark on the first jump, but not on continuation mode jumps. This would also exclude setting the mark for off-screen jumps, since that defeats the UX goal of "I want to return to where I started searching in one jump"

## NON-GOALS:

- [ ] Sneak mode. I see no need to make an inferior version of the original.
