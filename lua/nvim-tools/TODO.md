## General

#### TODO:

- [ ] Do I have the README store locally on both machines? Shows unpushed on laptop.
- [ ] Make sure everything has vim.validate in the params. It is easier for the user to remove than add them
  - Exceptions:
    - Validation functions (since they are, themselves, validators)

#### FUTURE:

- [ ] When https://github.com/neovim/neovim/issues/38420 releases, update everything to use it.
  - Specific Targets:
    * [ ] Option changes using misc.append_if_missing

## Buf

#### buf_open

###### TODO:
- [ ] Add an algorithmic save function
  - [ ] TODO scoped under the presumption that not all corner cases will be covered. Those can be prioritized down
  - [x] Should appropriately handle errors while saving
  - [ ] If there's no file on disk, should that file be created? Or is that an abort?
    - I think the way I have it right now is probably best, in that it should not insist upon itself if the file's not on disk. If/when bcd is added, I think an opt to use that to save to disk would make sense. Add a FUTURE note somewhere
- [ ] Canned script for creating a temp-buffer for window and tab opening purposes. See the code I have in vim-dadbod
- [ ] Add a get bcd function
  - Note that it might be supersceded when the feature is officially supported
- [ ] Possible new buf_open idea based on using temp buffers to direct the :help cmd

- [ ] See if it's possible to make :help do what we want by using temp buffers + window context
  - [ ] If so, this should be a wrapper around :edit/:help rather than bespoke code

###### MID:

- [ ] do_set_buf options
- [ ] It should be possible to provide your own post-load, pre filetype options
    - Idea: A callback is provided with buf as a param that's run in the proper window context. You can write your own custom options to set in there. Maybe provide a boolean for if this overwrites or appends to the default behavior
    - More Complex Idea: Do these option sets from a table. Allow the user to specify their own table along with merge behavior or total removal of the default
    * Problem: How do you handle setting opts based on programmatic conditions? You could use some kind of table function arg, but this is starting to sound goofy.
    - [ ] Make sure that ftdetect is handled for buftypes that are non-specific
- Like the ones that already exist, new options for this function should be layerable and composable, rather than creating new path dependencies
- [ ] An opt could be provided for setting the pcmark, but I don't know what the use case is

###### LOW:

- [ ] Smarter `open_buf` filetype detection:
  - With help and qf buftypes, the current trade-off is to sacrifice potential nuance in behavior and performance for reliability, both in avoiding filetypedetect and making sure ftlugins are always able to overwrite post-load settings
  - It may be possible, based on the previous buf/win settings, to let one of both of the FileType and filetypedetect events fire
  - This is tough because
    * Vim tracks if ftdetect occurred based on, seemingly, a few different backend settings. I would prefer not to get them and their meanings mixed up
    * `do_ecmd` and `open_buffer` do not have the same behavior. I would need to cross-reference both of them to get the result I'm looking for
    * At least for now, I have yet to see a use case that strengthens the cost/benefit analysis

#### Other

- [ ] Add an algorithmic save function
  - [ ] TODO scoped under the presumption that not all corner cases will be covered. Those can be prioritized down
  - [x] Should appropriately handle errors while saving
  - [ ] If there's no file on disk, should that file be created? Or is that an abort?
    - I think the way I have it right now is probably best, in that it should not insist upon itself if the file's not on disk. If/when bcd is added, I think an opt to use that to save to disk would make sense. Add a FUTURE note somewhere
- Canned script for creating a temp-buffer for window and tab opening purposes. See the code I have in vim-dadbod

## Config

#### META:

- Be cautious about adding new automatic config delete conditions. If the user, say, wants to add BufDelete, they can make their own autocmd.

#### TODO:

- [ ] Type annotate everything properly since Lua_Ls doesn't auto-detect everything.
  - [ ] Including fields in both metatables
  - [ ] Make them class exact? Unsure if I want to double-define the self methods though
  - [ ] Example from vim.pos of how to make metatable __call documented:
  ---@cast M +fun(buf: integer, row: integer, col: integer): vim.Pos

- [ ] Use this module as the template example for the docgen
  - [ ] Make sure metatable class documentation is correct

#### DOCUMENT:

- [ ] Invalid buf_ids in buf_config hard error
- [ ] The main config does not allow setting nil and does not allow for niling itself out. The buf configs do allow this
- [ ] Explicitly setting a buf config to nil clears it
- [ ] When :file or :saveas is used to change the name of a buffer, the new buffer takes the original buf-id, and the old file/filename are assigned a new one. buf_config performs no detection or bookkeeping here
  - [ ] Provide an example of how the user can do this with an autocmd or a bespoke cmd.

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

#### MAYBE:

###### Git

- Could be extracted in to a library, since what the proposed functions above provide is sufficiently novel

## opt

#### TODO:

- [ ] Opt parsers
  - [ ] Comma opt (for rancher swb overrides)
  - [ ] isk (Because I have it)
- [ ] with_opts() (rancher window opening)

## pos

#### DEPS:

#### META:

- Pos Names:
  * qf_pos (1 indexed, inclusive or exclusive, includes vcol flag)
    + I'm not sure this is a particular data type (there is no built-in Range3), but more a particular kind of state
      + I have never been clear on if this is end exclusive or not. It almost feels dependent on the beginning and end of the qf position. It also seems to depend on the source.
  * cur_pos (1 indexed rows, 0 indexed cols, inclusive)
    + In |api-indexing| this is referred to "mark-like" indexing, but cur_pos (for me) is such a common convention, I'm kinda stuck with it
      + Problem: cur_idx is not particularly clear as to the meaning in this context
      + cur_pos/mark_idx would be bad
      + Problem: cur_pos does not necessarily mean cursor
      + Maybe you do call it mark_pos
  * api_pos (0 indexed, end exclusive)
  * ext_pos (0 indexed, end inclusive)

- Range Names:
  * ts_range_4 (zero indexed, start is end inclusive, end is end exclusive)
  * regionpos_4 (one indexed, end inclusive or exclusive)
  * mark_regionpos_4

#### TODO:

- [ ] Need names for 1,1 inclusive and 1,1 exclusive

- [ ] Position conversion:
  - [x] api > ext
  - [x] api > mark
  - [x] ext > api
  - [x] ext > mark
  - [x] mark > api
  - [x] mark > ext

- [ ] Position adjustment
  - [ ] api
  - [ ] ext
  - [ ] mark

- [ ] Range4 conversion
  - [ ] 1,1 to ext (for farsight and rancher. Is that exclusive indexed or no?)
  - [ ] 1,1 region to mark (exclusive optional)

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

- There is a combinatorial problem of:

- Add resolve_qf_pos function
  * If vcol is true, get the proper end col
  * Might need an inclusive vs. exclusive flag

## range

#### TODO:

- [ ] Naming:
  - [ ] ts_4 (0 based, end pos is end exclusive)
    - could maybe be api_4 or lsp_4
  - [ ] mark_4 (both positions are marks based)
  - [ ] regionpos_4 (1,1, end inclusive or exclusive depending on source)
