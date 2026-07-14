## OBJECTIVES:

- [x] Live Jumping:
  - [x] Flash/lightspeed style jumping
  - [x] Support label re-use
- [ ] Static Jumping:
  - [ ] EasyMotion/Jump2D style jumping
- [ ] Csearch Plus:
  - [ ] This should support both classic searching as well as the enhanced f/t style
    - Primary motivation is so I can move live jumping to ;/, which frees the `s` key.

## CONSTRAINTS:

- AoS rather than SoA
  * Lua is not low-level enough to realize the benefits of SoA except with datasets larger than what we're dealing with here
  * Ergonomically working with SoAs involves repeatedly hashing table fields, which I am assuming also eats into the perf benefit
  * I have the tooling to work with lists of ranges
- Don't do the "it shouldn't be recursion" thing where it doesn't make sense
  * Trying to move the label generator to a queue-based system made it effectively impossible to reason about. Echasnovski was right.
- The broad-based goal here is to think in terms of algorithmic complexity and design wins that create leverage, not micro-opting.
- Don't muddy the waters by trying to make the search tools into nvim-tools modules. Focus on handling farsight.
- The names are Live, Static, and Csearch. This is not worth brainstorming on further.
- Don't bother doing anything with screen positioning. Too hard/slow
- Search results should be customized using patterns and maybe other on-rails options. Allowing user callbacks into the search results raises too complexities.
- Live jumps are always single window. Static jumps in normal mode are multi-window.
  * Multi-window live jumping introduces performance concerns
  * I want to keep the features differentiated

## DESIGN:

- [ ] The data flows, and how they all work together, need a lot of pre-attention, because being unable to manage this killed the previous version

- [ ] Need to figure out csearch traversal. Don't want to use bespoke UTF-8 if it can be avoided, but need correct by-char iteration.

- [ ] Something I goofed in the previous code - Dim should be applied to the searched area, not the target lines. This provides the user a visual indicator of where the search is happening

- [ ] Verify and note indexing for match_line or whatever.

- [ ] Highlighting
  - [ ] Live: Default the search terms to "search" and default the label to "IncSearch"
  - [ ] Static:
    - [ ] The key to press to jump should default to "IncSearch".
    - [ ] The current logic supports a "next key to press" and then a "future chars" color. Aside from being complicated to code, it doesn't add anything for the user.
      - [ ] I am fine supporting a highlight for "press this key to advance the jump state, but it won't actually jump" even though I don't use it. What color though? I would probably say either "Visual" or "Search" and not overthink it too much since it's trivial to customize. Also "CurSearch" is a possibility

- [ ] Fold handling
  - [ ] Static jumps should put a single label on folded lines. The current code does this
    - The folds `first` logic handles this
  - [ ] Live jumps should ignore folds
    - The folds `none` logic handles this
  - [ ] Csearch is weird because we don't want to draw extmarks for folds, but we need to account for them because of highlights relative to count. I forget how the current code handles this

- [ ] General search module:
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
  - [ ] Label location
    - [ ] Static: start/end/start+end/cursor-aware

- [ ] Csearch:
  - [ ] Do not do continuation mode in omode or on dot-repeat
    - Omode you can just handle with a flag in the private module. Dot repeat you probably have to always turn off.
  - [ ] Need to be mindful of when the stuff under the cursor is and is not deleted when using these motions with operators
  - [ ] Note: For default f/t, ;/, always advance by one, ignoring count. Count is only for the initial movement
  - [ ] pcmark options:
    - [ ] never
    - [ ] on screen change (probably default)
    - [ ] initial jump only (default?)
    - [ ] always
  - [ ] Dot repeat
    - Very roughly, this needs to allow us to enter the last continuation mode, so it isn't just lost
    - Question: Does dot repeat advance by the same count as before? I forget how the default works, but
  - [ ] For folds, f/t does indeed work in them, so we need a solution I guess.
  - [ ] Continuation mode raises a lot of weird questions about how much of the Quickscope style highlighting we need.

## TODO:

- [ ] Rewrite `/plugin` in one go once all the sub-modules are done, so we can just copy over what's in catharsis and replace as needed.

- [ ] Clean old files/code
  - [ ] Go through the code/TODO notes again
    - Code as a final sanity check that everything has been implemented properly
    - Notes because, especially in `plugin`, there is info related to publishing and Neovim issues I found while writing the old version
  - [ ] For `plugin`, this would involve clearing out old, commented code

#### LIVE:

- [ ] The experience of typing regex is unintuitive, because you want to get in and start doing micro-corrections, but that triggers the cursor moved detection
  - [ ] Maybe you tie label display and label jumps to the cursor being in the last position, then you can use cursormoved to check if they need to be disabled/re-enabled

## DOC:

- [ ] regex:match_line is used under the hood
  - [ ] Specifically meaning - Case sensitive under the hood

## PUBLISHING:

- [ ] Everything should use the "targets" and "target locator" branding
- [ ] Add `desc` values to Plug and default mappings
- [ ] Verify that the `require("farsight")` call in /plugin.lua does not require other files

## MID:

- [ ] For `nowrap` buffers, you can use `getwininfo()` to build the left and right bounds for line display, then filter out OOB results. Unlike with a lot of stuff dealing with screen positioning, this should be one or two data pulls from Neovim then the rest is Lua calculation.

#### LIVE:

- [ ] Handle buf versioning in case autocmds change the buffer
  - Problem: Currently, "has cached" means we are rewinding to a previous state and should not accept a jump label. I'm not sure how working with buf versions complicates that assumption.

- [ ] Don't just abort the search if the cursor moves back
  - Problem: I'm not sure how this affects assumptions around skipping label jumping if there's a cached version.

- [ ] Do tokens as codepoints rather than strings. Issue is having to do API calls for the conversions

- [ ] Allow folds `none` or `first`
  - Issue: Data typing and variables from the init module into the match module.

- [ ] Add option to autojump on only one result.

## LOW:

- [ ] For multi-win jumps, instead of freshly pulling every win, check previous results to see if there is overlap and stitch them together.
  - Multiple obstacles here:
    * Each window has different folds. What if ranges in a previous win were filtered that you want to use in the current one?
    * No memory savings, because the ranges need to be copied to avoid spooky action at a distance.
    * The functions for getting ranges would have to serve multiple masters.

* [ ] For targets gathering, is there a way to initially size the targets table based on the amount of bytes to search and the nature of the search? Because we already size to 16, it's hard to imagine a solution that doesn't create more perf cost.

- [ ] Omit a label from the first result, since `<cr>` always jumps to it.

#### LIVE:

- [ ] Improve performance.
  - On my computer, for very large searches, the total time spent outside of matching, setting extmarks, and redrawing is ~.2ms. This means any future improvements would be marginal, and can't add non-marginal complication to the code.
  - Idea: Merge adjacent search areas
    * Problem: A check for adjacent search areas would usually not find anything, and the user perceives nothing wrong if they are present.

- [ ] Labels changing based on the current set of end chars is fortunately rare, but is it possible to further minimize without increasing runtime too much?

## NON-GOALS:

- Sneak mode. There is no reason to make an inferior version of the original.
- Lightspeed has a feature where, if a unique end char is present, pressing said end char will jump to that result. This poses two problems though:
  * If you are typing through a result to narrow it to a label, you might press the key to jump without realizing
  * This is complex to implement
