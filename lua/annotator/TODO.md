## TODO:

#### Beforehand

- [ ] nvim-tools
  - [ ] Template config/init module
  - [ ] Can I actually name it nvim-tools?
    - I think I can
  - [x] echasnovski has a function somewhere for using Nvim's internal width variable to calculate the max length of error messages
  - [ ] A generalized version of farsight's buffer search
    - [ ] Get results
    - [ ] Fix data
    - [ ] Do basic filtering
      - [ ] folds
    - [ ] Include result iterators that would be useful for common tasks
      - [ ] Iter all positions for re-indexing
  - [x] Protected set cursor
  - [x] List tools
  - [ ] Table tools
  - [x] echo wrapper
  - [x] Protected Win Close
  - [x] Get listed bufs
  - [x] is_empty_buf
  - [x] Buffer close interface
  - [x] Open buf
  - [ ] Get indent
    - [ ] If no indentexpr, needs to handle the various indenting options
    - [ ] needs to handle all runtime indent args
  - [ ] Is pos in TS node
    - [ ] Research vim._comment
    - [ ] Research new TS incremental selection
    - [ ] Research how todo-comments does it
    - [ ] Properly handle injected languages
    - [ ] The form of the module should be to enter in a node name/type of your choosing
    - [ ] I have seen different comment node names in different languages I think you do a string.find for "comment" and that should do what needs to be done
      - [ ] This does then imply that the interface needs to have a param for contains vs exact matching
  - [ ] Does line contain TS node
    - [ ] Exact node name, node name to find, list of names
    - [ ] My best guess would be to use recursion, but would need more info/research
    - [ ] What does Folke's todo-comments function do?
    - [ ] How does autopairs handle this?
  - [ ] isopt parser
  - [ ] Char class parser

- [ ] Finish farsight
- [ ] Fix lampshade (plugin is fine, but needs config module for global/buf level)
- [ ] Fix rancher
  - [ ] Tons of different bug issues and API fixes/updates
  - [ ] Address the grep API issues found when creating that integration
    - [ ] It is neither intuitive nor explained why there is a what table param
      - Presumably, this is to be able to do things like enter a qftext func
      - It is not explained if any what values are mandatory
      - [ ] The user should be able to pass nil or an empty table to get default behavior
    - [ ] It should be possible to pass a string argument for locations
      - Or, if it would be better to keep it as a pure function arg, the defaults need to be documented
    - [ ] Fzf-lua's approach of having "pattern" and "regex" be separate inputs is superior to having a regex flag. More intuitive
      - Because you don't have to cross-reference two things in your head
    - [ ] The "QfrSystemOpts" link in the Grep documentation is incorrect.
    - [ ] The system sort arg should be able to take a string arg
      - Alternatively, the defaults should be listed
    - [ ] In sync, "syncrhonously" is a typo.
    - [ ] List default behaviors/options for SystemOpts and GrepOpts
    - [ ] SystemOpts and GrepOpts should be able to take nil values
    - [ ] Print additional information on error to msgs
      - [ ] Grep cmd (truncated if it's too long)
  - [ ] In system, add an on_list callback. This might be useful for editing the result type in helpgrep to `\1` in a less arbitrary way

- [ ] Research todo-comments
  - To help better understand the full scope of the problem
  - [ ] Are there other similar plugins?
- [ ] Research https://github.com/spywhere/vscode-mark-jump

- [ ] Since, for now, this is meant for internal use, delete any of the config from the init file
- [ ] Move anything important out of the `/plugin` file and delete that as well

- [ ] Need a name for this plugin/convention. In VSCode these are called marks, which does not fit with Neovim. Folke uses todo-comments. But I'm not sure that fits with [k]k navigation. On the other hand, "comment-navigator" is not a terrible plugin name.
  - Handle early because it's less to rename.

- [ ] Look into how gitsigns does its [c]c navigation

#### Meta Targets

- [ ] Include the colon as part of the annotation in all functions that use it
  - Saves concatenation
- [ ] All APIs should be accessible through init

#### General

- [ ] Make autocmd to clean buf commentstring cache on close

#### Helpers

- [ ] Get comment string
  - [ ] If cached, return cached
  - [ ] Get from buffer, cache and return

- [ ] Validate `cms`
  - [ ] Not nil
  - [ ] len > 0
  - [ ] Contains "%s"

- [ ] Get new annotation X from commentstring:
  - [ ] Replace `%s` with annotation plus an extra space
  - [ ] Return the formatted string plus the offset for where the extra space is
    - For insert mode cursor placement
    - Relevant for markdown comments, where you can't just append to the end

- [ ] Get border char
  - [ ] Iterate through `cms`
  - [ ] Each starting non-whitespace character should be the same, otherwise early return
  - [ ] Stop iterating at ` ` or `%s`
  - [ ] Return the iter char or nil

- [ ] Get indent
  - [ ] Should just be a copy paste of of nvim-tools

- [ ] Get Search Annotation (cms, annotation, startonly, grep strategy)
  - [ ] Get new annotation
  - [ ] Use offset and the grep strategy to put its version of `.*` after the space
  - [ ] Space characters are "one or more". This means something like `--    TODO: ` is valid
  - [ ] Also have to allow for variable spacing between `cms` elements.
    - The vimscript `cms` is `"%s`, but we would obviously want `" %s` to be valid
  - [ ] Non-whitespace parts of `cms` must match exactly
  - [ ] Assume we are on one line. For languages like Lua this doesn't really matter. But for markdown this means we need the start and end of the `cms` on one line.
    - Markdown example:
    {start of `cms`}{one or more spaces}{user annotation}{greedy .*}{one or more spaces}{end of `cms`}
  - [ ] If startonly, use the grep strategy to pin the search to the beginning of the line

- [ ] Search
  - [ ] Should basically be the nvim-tools extracted farsight search
  - [ ] Needs to handle counts for navigation
  - [ ] Depending on other data needs, perhaps don't use a SoA for results
  - [ ] Because, at least for now, we are using backwards and fwds for navigation (because we need to support wrapscan), have a dir flag that is -1, 1 or 0 (whole buffer)
  - [ ] For folds, either allow all results in folds or no folded results. We are assuming that we want to either skip over folds or see all results. First in fold doesn't make sense

#### Create Annotation

- [ ] Behaviors
  - [ ] Blank line
    - [ ] Get indent
    - [ ] Replace the blank line with the indented, new annotation
    - [ ] Based on the indent and offset, move the cursor and start insert
  - [ ] Shift down
    - [ ] Same as blank line, except nvim_buf_set_lines inserts instead of replaces
  - [ ] Append
    - [ ] If line has no trailing whitespace, add one space
    - [ ] All trailing whitespace on or after the cursor is overwritten
    - [ ] Get set point one space after last non-whitespace
    - [ ] Set text
    - [ ] Based on the set point and offset, move the cursor and start insert

- [ ] Dispatcher
  - [ ] Get and validate `cms`
  - [ ] Get new annotation from X and `cms`
  - [ ] if blank line then do blank line
  - [ ] else
    - [ ] if startonly, do shift down
    - [ ] else
      - [ ] if line has comment, do shift down
      - [ ] else do append

- [ ] Uses
  - [ ] MARKS are startonly
  - [ ] TODOs are not startonly

#### Buf Search

- [ ] Wrapper function
  - [ ] For now, always assume current buf and win context. Document this with the function
    - [ ] Altering window context is challenging because it affects cursor focus on :lopen
  - [ ] Get and validate `cms`
  - [ ] Get search annotation (account for startonly, strategy is vim regex)
  - [ ] Because we search by exact annotation, no filtering needed
  - [ ] Display results:

    - [ ] if fzf-lua:
      - [ ] Convert the indexing/data to what fzf-lua wants
      - [ ] Send it

    - [ ] else:
      - [ ] Get lines for qflist display
      - [ ] Turn the results into qf items
        - [ ] I think both qf and search indexing is 1, 1 but double check
      - [ ] Set the title to something like "annotator results"

      - [ ] if rancher:
        - [ ] Should have a public API to set a list with a title and take advantage of the "title_reuse" feature
        - [ ] Use the window APIs to open
      - [ ] else: Set loclist and open

- [ ] Uses
  - [ ] MARKS are startonly
  - [ ] TODOs are not startonly

#### Navigation

Wrapper function:
- [ ] Take dir
- [ ] Perform search with count
- [ ] Jump to the result
- [ ] Have an on jump callback
  - [ ] By default, handle `fdo` and `zzze` in here

Uses:
- [ ] MARK navigation

#### Integration Search

- [ ] fzf-lua
  - [ ] grep the annotation
- [ ] rancher
  - [ ] grep the annotation using fixed strings

#### Future Actions

- [ ] This should not linger as an internal plugin
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
- [ ] Integration search scoping:
  - [ ] Should be able to specify ignore hidden files as an option
  - [ ] Git files specific search
- [ ] Border addition improvements:
  - [ ] If a border is only found above or below, we can check to see if that border can be used for the current line. Check the line after the border to see if it is also a comment. If not, then we know it is not attached to some other comment item and can be re-used. Note that we are checking if the whole line is a comment, not if it merely contains one.
  - [ ] This function could also, optionally, detect if there is whitespace after the border and add it if not.
- [ ] Make internal searching support injected languages

## LOW:

- [ ] It should be possible for annotation adding to automatically add borders afterwards. The problem is that the user shouldn't be trapped in this behavior. For <esc> users, this is not an issue, as exiting insert mode with <Esc> would trigger the border addition, whereas <C-c> would cancel it. I'm not sure what the best key is for <C-c> users by default (though obviously it should be mappable to whatever the user wants). I'm also not sure how you detect what key is used to exit insert mode. Could be on_key. Could be a temp keymap.

## PR:

- [ ] For vanilla Vim - Change the vim.vim ftplugin `cms` to `" %s`
  - Their code uses this format
  - This would fit the recommendation from the Vim documentation
  - [ ] Check if this formatting is to address a complexity I'm not aware of
    - For example, not misinterpreting double-quoted strings in command contexts

## MAYBE:

- If `cms` cannot be found for a buffer, treat MARK as a relaxed annotation
- If `cms` cannot be found for a buffer, allow annotations through
- Idea for filtering CWD search results by valid `cms`
  - Get the grep result searching only for the annotation
  - Turn it into table list
  - For each item, iterate i and j (filter)
    * Track the last filename
    * Track if the last filename has a valid `cms`
    * If new filename, use filetype.match and filetype.get_option to get `cms`
      + If `cms`, then include and move i to j
      + If not, then don't increment j
    * For repeat filenames, handle j as needed
    * Save a filename/`cms` hash table
    * At the end of the first iteration, nil out extras
  - For each again
    * Get `cms` from hash table
    * Check if line is valid
    * Keep j if not, i to j then increment if so
  - Stress test with LLVM
  - Problem: This does not handle nested TS nodes

## NON:

- Don't ship a built-in external finder interface. Multiple other plugins address this problem
- Don't identify strict annotations based on the surrounding TS structure
  * This would create inconsistencies when reading results from unloaded buffers
