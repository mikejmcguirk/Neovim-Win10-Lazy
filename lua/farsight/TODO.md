## TODO:

- [ ] After all modules are done, rewrite `/plugin`.
  - Wait because holding both the old and new systems in `/plugin` is complicated to reason about.
  - Copy as much code from catharsis as possible.
  - Make sure necessary nuances from the old file are captured.
    * Example: The `<cr>` `maparg` check.
  - Properly handle all of the TODO notes in there

- [ ] Create checkhealth
  - [ ] Nvim version (current green, previous yellow, old red)
  - [ ] Map finding
  - [ ] Show options

- [ ] Verify no unnecessary modules required on startup

- [ ] Re-check that the farsight name is available

## TODO-DEP:

- [ ] When Neovim releases their multi-cursor functionality, make this plugin compatible
  - [ ] Static: I'm fine just disabling this when multi-cursor mode is active
  - [ ] Csearch: This needs to work as you'd intuitively expect
    - [ ] If you perform a search with multiple cursors that only some of them can accomplish, the cursors that cannot make the move should stay in place
      - An alternative would be to destroy the cursors that cannot make the move
    - [ ] In continuation mode, all the cursors should cycle through the results
  - [ ] Live: Labels should not display, and instead the `count` search result from each cursor should be highlighted to say "the cursor before this highlight will jump here".
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

## DOC:

- [ ] regex:match_line is used under the hood
  - [ ] Specifically meaning - Case sensitive under the hood

- [ ] Credits:
  - jump2d (initial basis for static)
- [ ] Inspirations:
  - Flash/Lightspeed/Leap (incremental jumping)
  - Quickscope (target display for f/t jumping)
- [ ] Alternatives
  - vim-sneak
  - hop
  - EasyMotion
  - https://github.com/dahu/vim-fanfingtastic
  - https://github.com/rlane/pounce.nvim
  - https://github.com/woosaaahh/sj.nvim
  - https://github.com/rhysd/clever-f.vim
  - https://github.com/svermeulen/vim-extended-ft
  - https://github.com/nvim-mini/mini.nvim/blob/main/readmes/mini-jump.md
  - https://github.com/ggandor/flit.nvim
  - https://github.com/nvim-mini/mini.jump

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
  - The problem is, what non-trivial gains can be gotten that don't non-trivially increase code complexity?

## ISSUES:

- [ ] Multi-line highlights do not behave well with window namespace scoping.

## NON-GOALS:

- Lightspeed has a feature where, if a unique end char is present, pressing that end char will jump. This poses two problems:
  * If you are typing through a result to narrow it to a label, you might inadvertently press the key to jump
  * This is complex to implement
