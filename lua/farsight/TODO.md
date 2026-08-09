## TODO:

- [ ] cut into a separate repo
- [ ] Remove nvim-tools refs

## TODO-DEP:

- [ ] When Neovim adds multi-cursor, make this plugin compatible

## DOC:

- [ ] regex:match_line is used under the hood

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

- [ ] Docs and internal code should use the "target" and "target locator" branding
- [ ] Verify that calling `require("farsight")` does not require needless files

- [ ] Re-check that the farsight name is available

## MID:

- [ ] For static and live, in `nowrap` buffers, use `getwininfo()` to build the left and right display bounds, then remove OOB results. (Also applies to csearch before continuation mode)
- [ ] Live and Static handle exclusive unclearly. Need to make a truth table based on the mode, selection, direction, and whatever else and make the logic more clear.

#### CSEARCH:

- [ ] API/map to re-enter previous continuation mode
- [ ] Don't exit continuation mode if the buffer changes but the cursor doesn't move
  - Use case: Built-in f/t motions support `fxry;ry` to make repeated small edits
- [ ] Exclusive/mode handling is spread out by virtue of the search based jumping. Confusing.
  - Might have to bite the bullet and use search just to find the position, then handle the adjustments afterwards so the logic can be centralized.

#### LIVE:

- [ ] State handling is hard to understand.
- [ ] Handle buf versioning in case autocmds change the buffer
  - Problem: Currently, "has cached" means we are rewinding to a previous state and should not accept a jump label. I'm not sure how working with buf versions complicates that assumption.
- [ ] Don't just abort the search if the cursor moves back
  - Problem: I'm not sure how this affects assumptions around skipping label jumping if there's a cached version.
- [ ] Do tokens as codepoints rather than strings. Issue is having to do API calls for the conversions

## LOW:

- [ ] For multi-win jumps, instead of freshly pulling every win, check previous results to see if there is overlap and stitch them together.
  - Multiple obstacles here:
    * Each window has different folds. What if ranges in a previous win were filtered that you want to use in the current one?
    * No memory savings, because the ranges need to be copied to avoid spooky action at a distance.
    * The functions for getting ranges would have to serve multiple masters.

* [ ] For targets gathering, is there a way to initially size the targets table based on the amount of bytes to search and the nature of the search? Because we already size to 16, it's hard to imagine a solution that doesn't create more perf cost.

#### CSEARCH:

- [ ] Add an "after" option in addition to "till".

## ISSUES:

- [ ] Multi-line highlights do not consistently display within window namespace scopes.

## NON-GOALS:

- Lightspeed has a feature where, if a unique end char is present, pressing that end char will jump. This poses two problems:
  * If you are typing through a result to narrow it to a label, you might inadvertently press the key to jump
  * This is complex to implement
