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

- [ ] Primitives
  - [ ] Get the correct nested TS node at a location
    - [ ] Look at vim._comment
    - [ ] Look at the new treesitter incremental selection
    - [ ] Look at todo-comments
    - [ ] Create a generalized interface
      - [ ] Add this to nvim-tools

  - [ ] Check if a nested TS node at a particular location is a comment
  - [ ] Check if a line is a mark annotation

  - [ ] fzf-lua
    - [ ] What grepprg is being used?
    - [ ] What is the output format?
    - [ ] How to use list formatter on items

- [ ] Features
  - [ ] MARK Navigation
    - [ ] Require a commentstring
  - [ ] Same buf MARK search
    - [ ] Only pull results from filetypes with a commentstring
  - [ ] CWD MARK search
  - [ ] Same buf TODO search
  - [ ] CWD TODO search

- [ ] Integrations
  - [ ] Fzf-lua grep strict cur buf
  - [ ] Fzf-lua grep strict cwd
  - [ ] Fzf-lua grep relaxed cur buf
  - [ ] Fzf-lua grep relaxed cwd
  - [ ] rancher grep strict cur buf
  - [ ] rancher grep strict cwd
  - [ ] rancher grep relaxed cur buf
  - [ ] rancher grep relaxed cwd

- [ ] Future actions
  - This should not linger as an internal plugin
  - Plugin ideas:
    * More quickfix integration? AFAICT, todo-comments only sends results there
      + This would, IMO be a better way to do highlighting
        + Though doing it like search highlighting is also fine
        + Caveat: Quickfix highlighting is something that should be implemented in Rancher. So, effectively, you're turning this plugin into a basket of canned Rancher highlight settings
  - Alternatives if a good plugin idea can't be figured out:
    - Separate out TODO navigation entirely and focus on the MARK aspect
    - Add some interfaces and Plug maps to my code

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

## MAYBE:

- [ ] If `cms` cannot be found for a buffer, treat MARK as a relaxed annotation

## NON:

- Don't ship a built-in external finder interface. Multiple other plugins address this problem
- Don't identify strict annotations based on the surrounding TS structure
  * This would create inconsistencies when reading results from unloaded buffers
