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

#### Checks at end
- [ ] Any function that takes an annotation var should not require the colon. The function should handle that part

#### Comment Node Detection
- [ ] Research vim._comment
- [ ] Research new TS incremental selection
- [ ] Research how todo-comments does it
- [ ] Properly handle injected languages
- [ ] The form of the module should be to enter in a node name/type of your choosing
- [ ] I have seen different comment node names in different languages I think you do a string.find for "comment" and that should do what needs to be done
  - [ ] This does then imply that the interface needs to have a param for contains vs exact matching
- [ ] Then it can be added to nvim-tools

#### Create Annotation
- [ ] Primitives:

  - [ ] Does a line contain a comment?
    - [ ] My best guess would be to use recursion, but would need more info/research
    - [ ] This function needs to take the vars it does, such as line, and only return a boolean, so that way it can be easily changed if need be

  - [ ] Insert annotation into commentstring:
    - [ ] Replace %s with the annotation plus an extra space
    - [ ] For cursor position calculation, return the format string as well as the offset from the beginning where the space is
      - [ ] Of importance for markdown style comments where you can't just insert after the end of the substitution

  - [ ] Does a buf have a valid commentstring?
    - [ ] vim.bo.commentstring is not nil and contains `%s`

- [ ] Steps

  - [ ] Blank line
    - [ ] Return if no commentstring
    - [ ] Get indent
    - [ ] Replace the blank line with the indented, calculated new annotation.
    - [ ] Move cursor and start insert based on substitution offset

  - [ ] Non-blank line
    - [ ] Return if no commentstring
    - [ ] If no append, do shift down
    - [ ] If append is allowed, check if row has a comment.
    - [ ] If row has a comment, do shift down, otherwise append

    - [ ] Append
      - [ ] Handle Pre-existing trailing whitespace
        - [ ] If the line has no trailing whitespace, add one space
        - [ ] All trailing whitespace after the cursor should be removed
      - [ ] Get set point
      - [ ] Get new text and offset
      - [ ] Set text
      - [ ] Move cursor based on set point and offset
      - [ ] Enter insert mode

    - [ ] Shift down
      - [ ] Basically the same logic as blank line, except nvim_buf_set_lines should be an insertion rather than a replacement

- [ ] Uses
  - [ ] MARKS should not allow appends (always overwrite current blank or insert new)
  - [ ] TODOs should try to append on non-blank lines

#### Check if a line has annotation X
- [ ] Steps

  - [ ] Fail if no commentstring
  - [ ] Assume we are on one line. For languages like Lua this doesn't really matter. But for markdown this means we need the start and end of the `cms` on one line.
    - Markdown example:
    {start of `cms` with space}{user annotation}{colon}{greedy .*}{end of `cms` with space}
  - [ ] If startonly, then `cms` must be the first non-whitespace character on the line

- [ ] Uses:

  - [ ] MARK needs to be startonly
  - [ ] TODO does not care about startonly

#### Same Buf Search for Annotation
- This logic should handle both navigation and same buf "grep"
- [ ] Whole Buf
- [ ] Backward
- [ ] Forward

#### Navigate Annotations

#### Search Stuff

  - [ ] Grep parsing
    - [ ] General filtering:
      - [ ] Do not accept results without a commentstring
      - [ ] For commentstring, need to do filetype.match() then filetype.get_option()
      - [ ] MARK
        - [ ] Get commentstring
        - [ ] Match beginning of line against comment string + mark
      - [ ] TODO
        - [ ] Get commentstring
        - [ ] If buf is loaded, check of results are in comment nodes
        - [ ] For unloaded bufs, accept all results with commentstring
    - [ ] fzf-lua
      - [ ] I'm not sure if the return here is a table or a text list
    - [ ] rancher
      - [ ] To start, add an on_list callback to system to filter results
        - [ ] Get unique bufnrs in results
        - [ ] Filter only results with `cms`
        - [ ] Do individual filtering
      - [ ] It would be better to be able to edit the text results directly, as this saves the effort of converting unused items to qf buffers
    - [ ] Single-buf
      - [ ] quit if no `cms`. Maybe vim.notify_once per buffer
      - [ ] Can do node-based lookup

  - [ ] Adding new MARKS:
    - [ ] blank line
    - [ ] Non-blank line
    - [ ] Cursor positioning must be based on %s, rather than an arbitrary end point. Have to take into account markdown style comments
    - [ ] Same with How insertion/spacing of the annotation is done

  - [ ] Adding new TODOs:
    - [ ] blank line
    - [ ] Non-blank line, append

  - [ ] Rather than bespokely parsing grep results, is it possible to use setqflist on the results to convert them
    - [ ] Benefit - Saves a lot of code writing. Allows navigation of results in more easily parsed format. If we are sending to qflist anyway, gets that step done early
    - [ ] Problem - This means we are doing qf parsing on results we will discard
    - [ ] A goofy but not 100% absurd idea would be to re-implement the Quickfix parsing, since this would help with converting it to Lua
  - [ ] fzf-lua
    - [ ] What grepprg is being used?
    - [ ] What is the output format?
    - [ ] How to use list formatter on items
  - [ ] rancher
    - [ ] What grepprg is being used?
    - [ ] What is the output format?

- [ ] Features
  - [ ] Add mark
    - [ ] Use the blank line or same line shift logic
  - [ ] Add TODO
    - [ ] Use the blank line or the same line append logic

  - [ ] MARK Navigation
    - [ ] How does Gitsigns do this?
    - [ ] Require a commentstring
    - [ ] Since we are in the same buf, we use the node detection first, then compare to commentstring
      - [ ] Node might not be necessary since the syntax is so specific
  - [ ] Same buf MARK search
    - [ ] Should not do anything if the current buf doesn't have a commentstring
    - [ ] Fzf-Lua
    - [ ] Rancher
  - [ ] CWD MARK search
    - [ ] Only pull results from filetypes with a commentstring
    - [ ] Use filetype.match and filetype.get_option
    - [ ] Fzf-Lua
    - [ ] Rancher
  - [ ] Same buf TODO search
    - [ ] Check comment nodes
    - [ ] Fzf-Lua
    - [ ] Rancher
  - [ ] CWD TODO search
    - [ ] Check TS in open files, otherwise accept
    - [ ] Fzf-Lua
    - [ ] Rancher

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
- [ ] If `cms` cannot be found for a buffer, allow annotations through

## NON:

- Don't ship a built-in external finder interface. Multiple other plugins address this problem
- Don't identify strict annotations based on the surrounding TS structure
  * This would create inconsistencies when reading results from unloaded buffers
