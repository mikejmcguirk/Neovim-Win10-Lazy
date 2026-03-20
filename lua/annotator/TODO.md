## OBJECTIVES

- For now, this will be an "internal plugin" focused on structured MARK handling and canned searches for TODO items.
  * The "strict" vs. "relaxed" search handling feels too goofy for a release
  * I don't know what to do with TODO comments that isn't just a less featureful version of folke's plugin

## TODO:

- [ ] Beforehand
  - [ ] Finish farsight, then fix rancher and lampshade
  - [ ] Rancher improvements
    - [ ] Address the grep API issues found when creating that integration
  - [ ] Research todo-comments
    - To help better understand the full scope of the problem
    - Are there other similar plugins?
  - [ ] Research https://github.com/spywhere/vscode-mark-jump

- [ ] Init Module
  - [ ] Options
    * [ ] If `cms` cannot be found for a buffer, optionally treat MARK as a relaxed annotation

- [ ] Integrations
  - [ ] Fzf-lua grep strict cur buf
  - [ ] Fzf-lua grep strict cwd
  - [ ] Telescope grep strict cur buf
  - [ ] Telescope grep strict cwd
  - [ ] snacks grep strict cur buf
  - [ ] snacks grep strict cwd
  - [ ] rancher grep strict cur buf
  - [ ] rancher grep strict cwd
  - [ ] Fzf-lua grep relaxed cur buf
  - [ ] Fzf-lua grep relaxed cwd
  - [ ] Telescope grep relaxed cur buf
  - [ ] Telescope grep relaxed cwd
  - [ ] snacks grep relaxed cur buf
  - [ ] snacks grep relaxed cwd
  - [ ] rancher grep relaxed cur buf
  - [ ] rancher grep relaxed cwd

- [ ] Future actions
  - I don't want this to linger as an "I'll get to this when I feel inspired" type thing
  - [ ] Make another push at seeing if there's a featureful plugin that can be built from this
    - One path forward might be to go all-in on the Quickfix integration. todo-comments, AFAICT, just sends the TODO items there and that's it
      * This would, IMO, also be a better way to do highlighting, even though it does add an extra step
      * Caveat: Any Quickfix highlighting thing should probably just be a part of rancher. Perhaps this plugin could have an integration where it sends canned highlight settings of some kind, but that in and of itself, IMO, is not a compelling enough reason to use this over TODO comments

## DOCUMENT:

- [ ] Strict vs. Relaxed matching
  * Strict: Looks for exact semantics and tolerates false negatives
    + [ ] Requires a `commentstring` value to be present
    + [ ] When searching unloaded buffers, if `cms` cannot be found using `vim.filetype.get_option()`, results from the buffer will be discarded
  * Relaxed: Only looks for if the annotation is in a comment. Tolerates false positives
    + [ ] When searching unloaded buffers, all results containing the annotation are accepted

+ [ ] For any annotations the user adds or deletes, they should be able to do so without the colon

## MID:

- [ ] Rancher list highlighting:
  - Rancher should provide a method so that, if the Quickfix list is open and a buf of an item in the list is visible, the Quickfix entries are highlighted
  - [ ] This should be controllable at the individual list level, not just from the stack as a whole
  - [ ] It should be possible to customize how the highlighting is done. So, for diagnostics, you might want to highlight the individual items based on diagnostic severity. Whereas, if you are looking at the results of a generic grep, you would use hl-search to highlight

## LOW:

## PR:

- [ ] For vanilla Vim - Change the vim.vim ftplugin `cms` to `" %s`
  - Their code uses this format
  - This would fit the recommendation from the Vim documentation
  - [ ] Check if this formatting is to address a complexity I'm not aware of
    - For example, not misinterpreting double-quoted strings in command contexts

## NON:

- Don't ship a built-in external finder interface. Multiple other plugins address this problem
- Don't identify strict annotations based on the surrounding TS structure
  * This would create inconsistencies when reading results from unloaded buffers
