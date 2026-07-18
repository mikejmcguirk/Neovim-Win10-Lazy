## OBJECTIVES:

- [x] Live Jumping:
  - [x] Flash/lightspeed style jumping
  - [x] Support label re-use
- [x] Static Jumping:
  - [x] EasyMotion/Jump2D style jumping
- [ ] Csearch Plus:
  - [ ] Supporting continuation style jumping is mandatory
  - [ ] Supporting class jumping is a bonus feature
    - Primary motivation is so I can move live jumping to ;/, which frees the `s` key.

## CONSTRAINTS:

- Don't muddy the waters by trying to make the search tools into nvim-tools modules. Focus on handling farsight.
- The names are Live, Static, and Csearch. This is not worth brainstorming on further.
- Don't bother doing anything with screen positioning. Too hard/slow

## DESIGN:

- The first jump
  + This should work like a standard f/t motion. 2fk should still jump two ks forward
  + Dimming should occur in the entire search area in the direction you want forward. You should, I hope, just be able to use the logic from live
- What is continuation mode
  + I think the constraint we need to accept is that the continuation options are only a set of the previous results
    + UX issue - Searching forward then dimming the whole screen for continuation is awkward
- Exiting continuation mode
  + Any non f/t action
  + we type things

- [ ] Need to figure out csearch traversal. Don't want to use bespoke UTF-8 if it can be avoided, but need correct by-char iteration.

- [ ] Highlighting: IncSearch > CurSearch > Search

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

  - [ ] needs to be compatible with the jake-stewart multicursor plugin
    - https://github.com/rhysd/clever-f.vim
    - https://github.com/svermeulen/vim-extended-ft
    - https://github.com/nvim-mini/mini.nvim/blob/main/readmes/mini-jump.md
    - https://github.com/ggandor/flit.nvim

## TODO:

- [ ] After all modules are done, rewrite `/plugin`.
  - Wait because holding both the old and new systems in `/plugin` is complicated to reason about.
  - Copy as much code from catharsis as possible.
  - Make sure necessary nuances from the old file are captured.
    * Example: The `<cr>` `maparg` check.

- [ ] Clean old files/code
  - [ ] Go through the code/TODO notes again
    - Code as a final sanity check that everything has been implemented properly
    - Notes because, especially in `plugin`, there is info related to publishing and Neovim issues I found while writing the old version
  - [ ] For `plugin`, this would involve clearing out old, commented code

#### LIVE:

- [ ] The experience of typing regex is unintuitive, because you want to get in and start doing micro-corrections, but that triggers the cursor moved detection
  - [ ] Maybe you tie label display and label jumps to the cursor being in the last position, then you can use cursormoved to check if they need to be disabled/re-enabled
  - [ ] You could also just have "very nomagic" as an option, but that also requires "smartcase" as an option which I want to avoid. Probably a documentation thing.

- [ ] Properly distinguish in state between having done a label jump and a cr jump.
  - [ ] Because we have to explicitly find and perform a label jump, `did_label_jump` is probably the better primitive than `did_cr_jump`

- [ ] `<cr>` should be based on count. `2;se<cr>` should go to the second result.
  - [ ] The `<cr>` destination should be highlighted with `CurSearch`
  - [ ] If `<cr>` is used to jump, auto dot-repeat should be enabled
  - [ ] If `<cr>` is used to jump, we should continue searching to find a valid result
    - [ ] Wrapscan should be either `false` (default), `true`, or `nil` (use Nvim option)
    - [ ] If there are fewer than `count` results and wrapscan is off, go to the last result
      - [ ] Otherwise, end up at the wrapped destination
  - [ ] If `did_cr_jump` or the like is not explicitly true, show labels during dot repeat
    - [ ] Dot repeat should, however, show the last search
    - [ ] How does this work with the pattern modifier? Do you save the last one or use the current one?
    - [ ] If you enter then cancel a jump in normal mode, does this overwrite the previous saved last jump? Probably not, as you want the last jump to be based on the last affirmative action

- [ ] Have an option to `show_labels`. Should be a function. Default should be a function that always returns true
  - [ ] You then need to make sure that the rest of the code reacts properly to this. Hash lookups are slow enough that you want to check the var always
- [ ] Have an option to auto-jump after X characters are entered
  - [ ] How do you handle regex atoms here?
    - Probably disable auto-jumping if an atom is typed. If the last character is a backslash, then allow auto-jump
- [ ] Document that you can disable labels + enable auto-jump for sneak-like behavior
  - [ ] Document that implementing sneak's labeling and vertical area based behavior are explicit non-goals. If you want to actually use sneak you should use sneak.

- [ ] Document a `show_labels` function that checks if we are in the multi-cursor mode of the `jake-stewart` plugin and disables them if so.
  - [ ] This then needs to actually work. The old `csearch` implementation plays well with the `jake-stewart` plugin so I know this is possible
  - I'm not sure though if we can get into like, highlights per cursor. That might need to wait for Neovim's official implementation.

## TODO-DEP:

- [ ] When Neovim releases their multi-cursor functionality, make this plugin compatible
  - [ ] Static: I'm fine just disabling this when multi-cursor mode is active
  - [ ] Csearch: This needs to work as you'd intuitively expect
    - [ ] If you perform a search with multiple cursors that only some of them can accomplish, the cursors that cannot make the move should stay in place
      - An alternative would be to destroy the cursors that cannot make the move
    - [ ] In continuation mode, all the cursors should cycle through the results
  - [ ] Live: Labels should not display, and instead the `count` search result from each cursor should be highlighted to say "the cursor before this highlight will jump here".

## DOC:

- [ ] regex:match_line is used under the hood
  - [ ] Specifically meaning - Case sensitive under the hood

- [ ] Credits:
  - jump2d (initial basis for static)
- [ ] Inspirations:
  - Flash/Lightspeed/Leap (incremental jumping)
  - Quickscope (target display for f/t jumping)
- [ ] Alternatives
  - vim-sneak (Farsight does not implement the "two-char f/t" style movement.)
  - hop
  - EasyMotion
  - https://github.com/dahu/vim-fanfingtastic
  - https://github.com/rlane/pounce.nvim
  - https://github.com/woosaaahh/sj.nvim

  - [ ] List these are credits, inspirations, or alternatives as ends up being appropriate:
    - https://github.com/rhysd/clever-f.vim
    - https://github.com/svermeulen/vim-extended-ft
    - https://github.com/nvim-mini/mini.nvim/blob/main/readmes/mini-jump.md
    - https://github.com/ggandor/flit.nvim

#### CSEARCH:

- [ ] `cpo-;` behavior is not implemented, and is not on the roadmap.

## PUBLISHING:

- [ ] Everything should use the "targets" and "target locator" branding
- [ ] Add `desc` values to Plug and default mappings
- [ ] Verify that the `require("farsight")` call in /plugin.lua does not require other files

## MID:

- [ ] For `nowrap` buffers, you can use `getwininfo()` to build the left and right bounds for line display, then filter out OOB results. Unlike with a lot of stuff dealing with screen positioning, this should be one or two data pulls from Neovim then the rest is Lua calculation.

#### CSEARCH:

- [ ] It would be good to have an "after" option in addition to "till"
  - [ ] Blocker: I have no idea where to map it. I don't think `<M-f>` or `<M-t>` are good defaults. Outlying compatibility issues plus not important enough to intrude on space often used for terminal and/or OS cmds.

- [ ] API to re-enter previous continuation mode

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

#### LIVE:

- [ ] Improve performance.
  - On my computer, for very large searches, the total time spent outside of matching, setting extmarks, and redrawing is ~.2ms. This means any future improvements would be marginal, and can't add non-marginal complication to the code.
  - Idea: Merge adjacent search areas
    * Problem: A check for adjacent search areas would usually not find anything, and the user perceives nothing wrong if they are present.

## ISSUES:

- [ ] Multi-line highlights do not behave well with window namespace scoping.

## NON-GOALS:

- Lightspeed has a feature where, if a unique end char is present, pressing that end char will jump. This poses two problems:
  * If you are typing through a result to narrow it to a label, you might inadvertently press the key to jump
  * This is complex to implement
