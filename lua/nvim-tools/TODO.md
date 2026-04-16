## General

#### TODO:

- [ ] The broader patterns described in the top level TODO doc all need to apply here
- [ ] I currently can actually name this nvim-tools, but check the big plugin collection repo before uploading

- [ ] Do I have the README stored locally on both machines? Shows unpushed on laptop.
- [ ] Make sure everything has vim.validate in the params. It is easier for the user to remove than add them
  - Exceptions:
    - Validation functions (since they are, themselves, validators)

- [ ] Create a template minimal init that can be used for plugin debugging. The Neovim repo has an example they use for minimal plugin init, though that might be superceded with vim.pack released

- [ ] The module should be documented using my docgen
  - [ ] Make sure meta-table class documentation is correct
  - [ ] Docgen should be able to handle this. It does so for vim.filetype

- [ ] Test to see if win_call_maybe and buf_call_maybe are faster than running them unconditionally. If so, add them here and use them in all the internals.A
  - [ ] Test with different % of times where you need to context call vs not

#### FUTURE:

- [ ] When https://github.com/neovim/neovim/issues/38420 releases, update everything to use it.
  - Specific Targets:
    * [ ] Option changes using misc.append_if_missing

## buf_open

#### TODO:

- [ ] This function requires a bit more polish. See comments there.
- [ ] Unsure if it's a design or documentation issue, but the times I've used this, I've been confused about what it's doing

#### LOW:

- [ ] It would be interesting if open_buf let you provide your own post load, pre-filetype options. But I'm loathe to add more features given that the function is already a bunch of hacks stitched together.
- [ ] It would be interesting if open_buf were smarter about when to fire filetypedetect and FileType events, but I don't want to add more failure points, especially given the complexity of FileType detection under the hood (in terms of where and why it fires)

#### MAYBE:

- Provide an opt for setting the pc mark
- Have the function gracefully error. Part of issue is the amount of control flow. Part of it is, since every other edit/buf opening function hard errors, this feels patternful. Part of it too is, it's meant to be a gut check on making sure the surrounding assumptions are correct.

## Buf

#### TODO:

- [ ] isopt parser
- [ ] Char class parser

#### MID:

- [ ] get_indent should properly handle smartindent
- [ ] For save(), pass a directory or a directory outputting function to save to if the file is not on disk

#### FUTURE:

- [ ] Build switchbuf handling
  - Waiting for concrete use cases
  - Want to let the other buf/win functions develop more before adding switchbuf handling as another element to handle
  - The two main pieces of logic seem to be buflist_getfile() (buffer.c) and swbuf_goto_win_with_buf() (window.c).
  - qf_jump_edit_buffer calls buflist_getfile() directly
  * Current thinking:
    + nil switchbuf = use the global option
    + empty switchbuf = use current window
    + non-empty switchbuf = use the opt override

- [ ] Add functions to open a buf in a split/vsplit/newtab. Waiting for more use cases
  - Particularly with rancher, since I need to see how to work around the special quickfix rules

- [ ] resolve_full_bufname is currently a placeholder. Want to see a few different use cases for a function like this before I decide what it is
  - Complicated by nofile buffers, which don't/can't have a bufname but are valid
  - Run bufadd and make sure it provides a valid return?
  - Run fs_access to verify the file is present?
    * Conceptually this is the most obvious. But, if you run buf_to_full_bufname, running a file system opt is nasty if the user just wants to resolve the data representation.
      + You could argue that buf_to_bufnr does the same thing on a string input, but since we have to run bufadd in bufname_to_bufnr, I'm fine with also throwing in the fs_access for more specific error reporting.
    * Doesn't help that I'm not sure what the use case for buf_to_ functions is in general

#### MAYBE:

- Add a higher-level "open_buf_in" function that takes an integer|split|vsplit|tabnew opt. Trickier than it seems though because of how the opts/vars get moved around, and I don't have a concrete use case.
  - Additional issue, with rancher, the qf state management is intermingled with the buf opening/win handling. That is probably bad, but I don't want to do this kind of buffer opening in the abstract without knowing what the concrete issues to work around are. Are there certain returns we might need?

## Config

#### META:

- Be cautious about adding new automatic config delete conditions. If the user, say, wants to add BufDelete, they can make their own autocmd.

#### TODO:

- [ ] Type annotate everything properly since Lua_Ls doesn't auto-detect everything.
  - [ ] Including fields in both metatables
  - [ ] Make them class exact? Unsure if I want to double-define the self methods though
  - [ ] Example from vim.pos of how to make metatable __call documented:
  ---@cast M +fun(buf: integer, row: integer, col: integer): vim.Pos

- [ ] When performing a __call merge, all values should be tried. All errors should be collected and printed to console upon completion.
  - [ ] Before performing the merge, save a copy of the previous table. If an error is found, rewind the table state.
    - Reasoning: The previous state of the config is assumed "good". A new config state with some good values and some values unchanged due to errors is presumed "bad"

- [ ] Config should be able to export checkhealth info
- [ ] For checkhealth, iterate over pairs to get active BufConfigs.
  - [ ] Not totally sure how to handle the case where you have a bunch of buf configs. Do you maybe pass an option to checkhealth? (Would document how to do this). It would be interesting/useful if you could designate fold regions in the checkhealth output.
  - `require("plugin").config:get_health()` and `require("plugin").buf_config:get_health()`

- [ ] When running an API function that relies on some piece of sub-config, the config metatable should provide a means to do the following:
  - [ ] Pass the user table as an argument
  - [ ] Validate the user table against the validators
    - [ ] Failure is a hard error
    - [ ] Extra values should be ignored
    - [ ] Nil values in the passed config would always be acceptable
      - [ ] Might be a plugin meta-design note that "opts" should always map to something in config and that all opts should be actually optional. Mandatory values should be args or a separate table
  - [ ] Merge in buf config with "keep" behavior
  - [ ] Merge in config with "keep" behavior
  - [ ] A "skip validation" opt should be provided for performance (would be used for built-in plugs). This option should either be internal or marked as unsupported/unsafe/undefined if bad values are passed
  - [ ] A question is - How do you handle when internal code needs to use public interfaces?
    - You could have a merge opt of "use_defaults", where user config is skipped. This would be predictable, but risks skipping user-defined behavior when it's desired
    - You could also just require any opts that need to be static to be passed explicitly, but this risks either falling into traps of unexpected behavior due to user opts or just ending up passing all opts to every internal function to make sure nothing goofy happens
    - In spite of causing more work, I think the latter option might be better because it avoids the problem of default config changes causing problems downstream.
  - [ ] When buf_configs are added or changed, should they be merged into the default with "force" behavior and the results cached?
    - I can feel the complexity surface area here. Feels like this should be responsive to a genuine perf issue. Though, in that case, the concept itself needs to be reconsidered.

#### DOCUMENT:

- [ ] Provide examples of how the config would be used/setup
  - [ ] For both main and buf_config
- [ ] Invalid buf_ids in buf_config hard error
- [ ] The main config does not allow setting nil and does not allow for niling itself out. The buf configs do allow this
- [ ] Explicitly setting a buf config to nil clears it
- [ ] When :file or :saveas is used to change the name of a buffer, the new buffer takes the original buf-id, and the old file/filename are assigned a new one. buf_config performs no detection or bookkeeping here
  - [ ] Provide an example of how the user can do this with an autocmd or a bespoke cmd.

- [ ] In the documentation for buf_config, show an example of using an autocmd to get project information and set an appropriate buf option

- [ ] Perf notes:
  - [ ] The module is designed around type safety, flexibility, and high-level abstraction
  - [ ] This necessarily creates a performance tradeoff
  - [ ] When performance tradeoffs beyond the baseline requirements of properly traversing the meta-table are required, favor off-loading those to table write
    - [ ] The module assumes that table reads might be performed in paths where responsiveness is a design goal
    - [ ] On the other hand, the module writes are limited to initialization or user-prompted function calls, rather than plugins trying to write in perf dependent paths

- [ ] Buf config design notes:
  - [ ] This cannot work:
  ```lua
  plugin.buf_config[0]({plugin.get_default_config()})
  ```
    - __index doesn't know what will happen after indexing
      - Because of this, if we make the assumption that a top level __index could lead to creating a new config, we would always have to create a new config on __index if it's nil, recursively checking afterwards if the table exists and removing if not
      - This crushes perf, because then *any* read on a nil sub-table requires creating a new config, then waiting for a function return to tell us if the table is empty, and deleting it if it is
  - Therefore, to create a new buf_config, the form needs to be:
  ```lua
  plugin.buf_config[0] = plugin.get_default_config()
  ```
  This will hit the buf_config_accessor as a __newindex and can be handled properly
    - Alternatively, you could do:
    ```lua
    plugin.buf_config:new(0, {})
    ```
      - This is not how vim.b works
      - This creates a duplicative interface pattern

#### MID:

- [ ] For maintaining deprecation plans, it would be better if there were a way to control the defaults. So if you change a default, you could have opt-in/opt-out behavior

- [ ] Outside of any specific use case, __index and __newindex should provide return values that allow the caller to understand what happened below so that proper follow-up action can be taken
  - [ ] nil > nil?
  - [ ] nil > value?
  - [ ] value > nil?
  - [ ] value > value?
  - [ ] validation failure?
  - [ ] This implies some sort of binary based flag so the return statuses can be layered performantly and in all combinations.

- [ ] When a config is written to, it should:
  - Check if it's a buf config
  - If so, check itself to see if any non-nil config values remain
  - If not, signal that it should be deleted
  - On delete, the bufwipe autocmd should also be removed

  - Challenges
    - This cannot trigger on read, because we are assuming that reads should be as performant as possible
    - This would need to be detected within a proxy table on __newindex. Feels like you would first need to send a "did_write" value up the call stack, then use that to trigger the recursive value check

- [ ] Provide a principled solution for skipping buf config on merge
    - [ ] Perhaps providing a nil buf arg, since 0 resolves to the current buffer
    - While I would prefer this behavior not even be possible, there's nothing to stop hacking it in with a scratch buffer, so I'd rather not be inconvenient on purpose

#### LOW:

- [ ] Is it possible to have a Root_Proxy that solely contains the __call method?
  - Problems: Both the __call method itself as well as __newindex rely on being able to use __call recursively

- [ ] Is it possible to put proxies on the non-config sub-tables in a way that (a) isn't contrived and (b) doesn't hurt PERF.
- [ ] It might be faster, for deleting autocmds, to check a cache for the group id rather than re-constructing the name string. I'm not sure this matters enough to justify maintaining the state.
  - [ ] Counterpoint: This also might matter for __newindex, meaning we're saving more perf
    - [ ] Counter-counterpoint: I think it's a mistake to make too many assumptions about state and how state is built

#### FUTURE:

- When g/b variables are able to store metatables, Show how to setup the code in the /plugin file without requiring an exterior module
  - Should the lua-module based config not be demonstrated at all? Unsure how to do so without creating duplicate code, since the point of the above is to avoid external requires.
  - Could maybe, instead, do the config in a module like it is now, then show a doc example on how to use in /plugin

  - [ ] As bcd/workspace config are added, does this prompt updates/changes?

#### MAYBE:

#### NON:

- Don't auto-create new buf_configs if you __index into a nil buf_config
  * Actual Lua tables don't behave this way, so it's an anti-pattern
  * This behavior would then require a bespoke accessor function to check if a config exists and is not empty before actually reading the value(s) from it
  * Correctly handling "gc" for empty buf configs is tricky. Don't want to introduce conditions under which tables can be needlessly created

## fs/git

#### DEPS:

- Neither fs nor git, IMO, should proceed without a generalized method for async with await. Maybe it's vim.async. Maybe it's learning co-routines.

#### GOALS:

###### Git

- Provide primitives and wrapper functions for interacting with Git + Nvim
  - Example: Git delete primitive which checks the git status of the file, and performs the proper deletion, or does nothing
    - Would include an opt for whether or not to remove from disk
  - Example: GBufDelete, which performs the underlying GDelete, then handles the buf + file on disk based on what was done in git.

#### TODO:

###### Git

- [ ] rm from git
- [ ] git rm + rm buf
- [ ] is file get tracked
- [ ] get head status
- [ ] git mv
- [ ] git mv + buf mv
- [ ] get raw diff
- [ ] format diff
- [ ] get diff counts
- [ ] get diff of unsaved buffer
- [ ] get blame for current line
  * [ ] blame for range?

- [ ] Look through git fugitive and git signs
  * Outright re-implementing fugitive is a bad idea. While a Lua rewrite would almost certainly be more performant and easier to maintain, fugitive solves a complex problem and does so effectively.
    + But because it's so feature complete, there are almost certainly functions that can be extracted from it
  * While git signs points to the kinds of primitives that should be created, the plugin itself is close to perfect.

###### fs

+ [ ] unlink
+ [ ] mv
+ [ ] mkdir
  + [ ] mkdir -p
- [ ] A version of glob that only returns result count (save heap allocations)
- [ ] get_file_perms could probably be a general file info view
  - [ ] File size
  - [ ] mtime
  - [ ] Created

#### MAYBE:

###### Git

- Could be extracted in to a library, since what the proposed functions above provide is sufficiently novel

## Misc

#### TODO:

- [ ] wrapping add/wrapping sub

## opt

#### TODO:

- [ ] Opt parsers
  - [ ] Comma opt (for rancher swb overrides)
  - [ ] isk (Because I have it)
- [ ] with_opts() (rancher window opening)

## pos

#### META:

- Pos Names:
  * qf_pos (1 indexed, inclusive or exclusive, includes vcol flag)
    + I'm not sure this is a particular data type (there is no built-in Range3), but more a particular kind of state
    + I have never been clear on if this is end exclusive or not. It almost feels dependent on the beginning and end of the qf position. It also seems to depend on the source.
  * eval_pos (1, 1 inclusive)
  * {need a name for 1, 1 exclusive}
  * mark_pos (1 indexed rows, 0 indexed cols, inclusive)
  * ext_pos (0 indexed, end inclusive)
  * api_pos (0 indexed, end exclusive)

#### TODO:

- [ ] Position conversion:
  - [x] api > eval
  - [x] api > ext
  - [x] api > mark
  - [x] eval > api
  - [x] eval > ext
  - [x] eval > mark
  - [x] ext > api
  - [x] ext > eval
  - [x] ext > mark
  - [x] mark > api
  - [x] mark > eval
  - [x] mark > ext

- [ ] Position adjustment
  - [ ] api
  - [ ] eval
  - [ ] ext
  - [ ] mark

- [ ] Range4 conversion
  - [ ] eval > ts_range
  - [ ] eval > ext_range
  - [ ] regionpos to mark (exclusive optional)

- [ ] Pos functions
  - [ ] cmp_pos (returns -1, 0, 1 like vim.pos does)
  - Do these if they have more efficient code paths than just checking the result of cmp_pos
    - [ ] eq
    - [ ] lt (not lt == >=)
    - [ ] gt (not gt == <=)

- [ ] Range functions
  - [ ] contains
  - [ ] intersect
    - [ ] Lots of ways you could do this, but look at treesitter to see what matters in practice

- [ ] Pos and Range functions
  - [ ] pos lt
  - [ ] range contains
  - [ ] pos gt

- [ ] Add resolve_qf_pos function
  * If vcol is true, get the proper end col
  * Might need an inclusive vs. exclusive flag

## range

#### META:

- Range Names:
  * Any reuse of the above names means that both positions in the range use the pos indexing. So mark_range_4 would be two mark positions. ext_range_4 would be all zeroes.
    + So mixed position indexing, like treesitter ranges, need their own names
  * ts_range_4 (zero indexed, start is end inclusive, end is end exclusive)
    + Or lsp_range_4?
  * regionpos_4 (one indexed, end inclusive or exclusive)

## Search

#### META:

- Thinking ahead to the farsight case, the search results struct needs to be a subset of the targets struct
- I am basically fine with the idea that we perform the actual filtering and editing of the search results in the search module, and that in farsight the labeling presumes we are using all results.
  - Caveat: Handling label re-use, since we need hashed search results. I'm not sure if that's something we build here since it's more generalizable
  - I'm not sure how this idea interfaces with the notion of not labeling all results. I guess we would just only take in so many labels.

- I'm not sure if this is fixed in farsight, but the "dir" opt is vague. Should not be used.

- Must handle wrapscan as an opt
  - In farsight, this would just be removed. The annotator/grep cases are more interesting, because for nav, you set it to default true in config, but for buffer searches, where do you set it for false so it's not fiddled with?

- The search needs to return in some way where the ordering of the results makes sense. Like, based on the direction entered into the search, the results should return such that the first result is always the "best" one. Should not need to read flags for iteration.

#### TODO:

  - [ ] The "results" module in farsight seems like the best model to start with. I forget which of the farsight modules has the most up-to-date search implementation. I think the one that's LuaJIT only.

- [ ] An open but important question is where valid is stored. The way I think it is right now is that the search module has no concept of this, so that would not be something to handle here.

- [ ] Is ther a better way to handle backward searching with wrapscan than an actual backward search?
  - Even without wrapscan, if you only want x results, or you have to manage count, tricky if you're searching forward

- [ ] Case sensitivity needs to be handled properly. I believe that, in the absence of regex atoms, ignorecase/smartcase are respected. I see no reason to disturb that behavior. But if you use an opt to manually specify a casing, then the search module needs to edit/cleanse the search string so that the proper casing is used.
  - Another case where I'd have to do... something in farsight to make it work right, since all searches should be exact case.

- Go through the old stuff to see what actual trimming is done to the results (there's a lot for handling things like how LuaJIT adds results or incomplete atoms and so on)

- [ ] Search Ranges
  - [ ] Entire Buf (wrapscan or no wrapscan)
    * [ ] Really the entire buf
    * [ ] Before cursor
    * [ ] After cursor
  - On Screen (wrapscan or not wrapscan)
    * [ ] Whole screen
    * [ ] Before Cursor
    * [ ] After cursor

- [ ] Result order
  - [ ] Top to bottom
  - [ ] Closeness to origin
    * [ ] This only makes sense if you're doing on direction from cursor, otherwise it would just be top to bottom

- [ ] The nvim-tools version of this needs to be feature complete, so we're looking at
  - [ ] fold elimination
    * [ ] keep all
    * [ ] remove all
    * [ ] keep first
      + [ ] based on result direction
      + [ ] or based on top to bottom
  - [ ] LuaJIT and Puc Lua support
    * [ ] Note the PUC Lua limitations

#### MAYBE:

A specific flag to reject blank lines or all-whitespace lines. This would be most relevant when dealing with multi-line results, as the end of a result might be on a blank line. I guess you'd have to look for results on a blank line, and either move the start/end points to non-blanks or just remove them. But that risks creating overlapping results. This feels secretly complicated and should be avoided without a concrete use case.

## Tab

#### TODO:

- [ ] Tab open function (need to handle count and such)
  - [ ] If you want to specify a buf, do you need to do open_buf in order to properly handle help wins? Probably.

## Treesitter

- [ ] Is pos in TS node
  - [ ] Isn't this basically done?
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

## UI

#### TODO:

- [ ] Generic get_input function that handles the "keyboard interrupt" case properly

## Win

#### TODO:

- [ ] Create an is_filline_visible function
  - Currently used in farsight
  - Rancher might need this for zzze handling after jumps

#### MAYBE

- Some kind of winnr to win-id function. All it is is tabpagewinnr, so for the most part there's no point in a wrapper unless you want something to convert tab-id to tabnr. I don't have a use case for this, so will pass for now.
  * In rancher, I get the tabnr once and then use it for everything else, so a wrapper would create more crossing of the Lua bridge
