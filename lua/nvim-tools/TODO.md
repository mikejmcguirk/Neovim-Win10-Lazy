## General

#### TODO:

- [ ] I currently can actually name this nvim-tools, but check the big plugin collection repo before uploading

#### DOCUMENT:

- [ ] Commenting guidelines:
- [ ] Annotation comments:
- Give an overview of how the function works for devs who want to know, broadly, what it does, without deep-diving into the details.
* Example: The pos functions do not require deep explanation
* Functions with longer annotation comments, therefore, imply that there is more you need to know
- For functions that would be public facing, like config or search, provide a template for how they would be documented to end-users
- [ ] Standard comments
  - Deep dive details
- Why certain choices are made (search() needs a lot of these)

- [ ] Needs a README

#### FUTURE:

  - [ ] The module should be documented using my docgen
  - [ ] Make sure meta-table class documentation is correct
  - [ ] Docgen should be able to handle this. It does so for vim.filetype

- [ ] When https://github.com/neovim/neovim/issues/38420 releases, update everything to use it.
  - Specific Targets:
    * [ ] Option changes using misc.append_if_missing

## buf_open

#### LOW:

- [ ] It would be interesting if open_buf let you provide your own post load, pre-filetype options. But I'm loathe to add more features given that the function is already a bunch of hacks stitched together.
- [ ] It would be interesting if open_buf were smarter about when to fire filetypedetect and FileType events, but I don't want to add more failure points, especially given the complexity of FileType detection under the hood (in terms of where and why it fires)

#### MAYBE:

- Provide an opt for setting the pc mark
- Have the function gracefully error. Part of issue is the amount of control flow. Part of it is, since every other edit/buf opening function hard errors, this feels patternful. Part of it too is, it's meant to be a gut check on making sure the surrounding assumptions are correct.

## Buf

#### MID:

- [ ] get_indent
  - [ ] Should probably handle smartindent
  - [ ] Should take an optional curpos argument for setting temporary cursor context when running the indentexpr (for calls to `line(".")`). Unsure what the right interface is though
    - Use case: Indenting multiple lines
- [ ] For save(), pass a directory or a directory outputting function to save to if the file is not on disk
- [ ] The isk module should also be able to handle isf, isi, and isp

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

* Remove get_bcd when an official implementation is created.

#### MAYBE:

- Add a higher-level "open_buf_in" function that takes an integer|split|vsplit|tabnew opt. Trickier than it seems though because of how the opts/vars get moved around, and I don't have a concrete use case.
  - Additional issue, with rancher, the qf state management is intermingled with the buf opening/win handling. That is probably bad, but I don't want to do this kind of buffer opening in the abstract without knowing what the concrete issues to work around are. Are there certain returns we might need?

- create_temp_buf sets ft at the end on principle. Change if this becomes a problem anywhere.

- I feel like protected_del should swap a temp buf into the current window if it's the last one. But that feels too complicated for a function that should be able to handle a bunch of different things.

- Provide to save the option to write to disk to some directory if `#bufname` == 0.
  * Could bcd or workspace config be used here?

## Config

#### META:

- Be cautious about adding new automatic config delete conditions. If the user, say, wants to add BufDelete, they can make their own autocmd.

#### DEPS:

- [ ] Docgen. Because of the nature of how the config is designed, I need to know where the docgen lands in order to actually write the documentation.

#### DOCUMENT:

- [ ] Config.__newindex is required to set nils in buf configs

- [ ] For non-config subtables, full replacements are required for validation. Direct editing of those tables is free-form.

- [ ] Buf accessor failure to read behavior is the same as vim.b

- [ ] All class components meant to be used by the public. Use dummies of needed.

- [ ] Use the default config to test the docgen's ability to pull literals

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

- [ ] Performing a full config merge each time a function is run is slow. It would be better if the merged configs were saved somehow
  - Solution 1: Keep a saved merge of buf_config and main config
    - Presumably, this would be in buf_config
    - Fine because it puts the perf cost in write
    - Keeping the state synced would be hard, especially if a change is made to config (does that have to propagate to all buf configs?)
  - Solution 2: Save specific merges
    * Similar issue to the above though - How do you know if a merge is stale?

- [ ] For maintaining deprecation plans, it would be better if there were a way to control the defaults. So if you change a default, you could have opt-in/opt-out behavior

- [ ] How to make the buf_config config sub-returns automatically type annotate

- [ ] Outside of any specific use case, __index and __newindex should provide return values that allow the caller to understand what happened below so that proper follow-up action can be taken
  - [ ] nil > nil?
  - [ ] nil > value?
  - [ ] value > nil?
  - [ ] value > value?
  - [ ] validation failure?
  - [ ] This implies some sort of binary based flag so the return statuses can be layered performantly and in all combinations.

- [ ] The validation should move first without collecting errors. If a problem is found, stop the first traversal and make another one to gather the errors. Let the standard case be fast.

#### LOW:

- [ ] Is it possible to put proxies on the non-config sub-tables in a way that (a) isn't contrived and (b) doesn't hurt PERF.
- [ ] It might be faster, for deleting autocmds, to check a cache for the group id rather than re-constructing the name string. I'm not sure this matters enough to justify maintaining the state.
  - [ ] Counterpoint: This also might matter for __newindex, meaning we're saving more perf
    - [ ] Counter-counterpoint: I think it's a mistake to make too many assumptions about state and how state is built

#### FUTURE:

- [ ] When g/b variables are able to store metatables, Show how to setup the code in the /plugin file without requiring an exterior module
  - Should the lua-module based config not be demonstrated at all? Unsure how to do so without creating duplicate code, since the point of the above is to avoid external requires.
  - Could maybe, instead, do the config in a module like it is now, then show a doc example on how to use in /plugin

- [ ] As bcd/workspace config are added, does this prompt updates/changes?

#### MAYBE:

- Iterate through config with a visitor pattern.
  * Problems:
    + Writing the iter code to accommodate all possible things the visitor function wants to do requires managing a lot of theoretical state simultaneously
    + For new table merges, I'm not sure what the principled solution is, since you need to track the sub-key when you hit nested Configs.
      + Could be keep a list of keys and use table.get(), but now you are keeping track of and resizing a table + unpacking it on call. Quite heavy.

+ Allow get_merged_config to skip validation.

#### NON:

- Don't auto-create new buf_configs if you __index into a nil buf_config
  * Actual Lua tables don't behave this way, so it's an anti-pattern
  * This behavior would then require a bespoke accessor function to check if a config exists and is not empty before actually reading the value(s) from it
  * Correctly handling "gc" for empty buf configs is tricky. Don't want to introduce conditions under which tables can be needlessly created

* In config merging, don't allow skipping buf config. If you don't want it, don't set it.

## fs/git

#### DEPS:

- Neither fs nor git, IMO, should proceed without a generalized method for async with await. Maybe it's vim.async. Maybe it's learning co-routines.

#### GOALS:

###### Git

- Provide primitives and wrapper functions for interacting with Git + Nvim
  - Example: Git delete primitive which checks the git status of the file, and performs the proper deletion, or does nothing
    - Would include an opt for whether or not to remove from disk
  - Example: GBufDelete, which performs the underlying GDelete, then handles the buf + file on disk based on what was done in git.

#### FUTURE:

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

## List

#### MID:

- "list and list" functions. Common enough patterns that you should be able to do `foo(list, list)` and get a result:
  * Filter by list. Items in the right are removed from the left. You can apply a transform to list a and/or b
  * A recursive find function like the list validator uses. So you have lists a and b. Every item in a must also be in b. You can apply a transform function to list a and/or b
  * For transforms, look at how find() does it

## opt

#### MAYBE:

- There is theoretical value in making a lightweight version of vim._with for private use. In practice, the only real use case is rancher's spk open. Would rather just handle that for now and borrow _with's pcall unpacking logic. Can revisit if needed.

## pos

#### TEST:

- [ ] You could be able to do conversion loops between different pos types and get the same result you started with

#### MAYBE:

- Add leq and geq functions, since getting to them through negation could be confusing
- More sophisticated error handling if nvim_buf_get_lines fails. My current theory is, if a bad row + buf is passed to the function, this should hard error (a) for visibility and (b) to prevent bad results from being used upstream
  * Same comment applies to string.byte
- Use graphene aware utf positions if a use case comes up. I just really hate to do this because it's slower
- The uint validation in these functions is load bearing because it prevents sub-zero values. In a real implementation in hot paths, vim.validate would not be present. But I also hate to speculatively make changes based on theoretical data breakage. The position adjustments are based on the premise of correcting stale positions after buffer changes. I have not seen negative values pollute positions before.

## range

#### META:

- At least for now, doing range conversions as in-place conversions. Unlike positions, there's less motivation to take them out of a table structure. Doing them in place prevents additional allocations.

#### FUTURE:

- Lots you could do with ranges, but will wait for use cases
  * Treesitter cmps might matter

## Types

#### MID:

- validate_list
  * Probably remove opts.func
  * item_type needs to be able to take a function

## Search

#### DOCUMENT:

- [ ] The search opts are a useful test for the docgen since they contain inherited class definitions.
  - [ ] Check inlinedoc vs without.

- [ ] In CommonOpts.patternfilter, document examples of:
  - [ ] Forcing case
  - [ ] Forcing fixed strings
  - Blocker - Understanding how the docgen renders markdown > Vimdoc

- [ ] Is there a way to deal with how long the function param type is in Results:sort_by_both_pos?

#### MID:

- [ ] For search_area, include support for using the results of getwininfo to filter off-screen matches on non-wrapped buffers.
  - Roughly, the left boundary would be used as the init_col, and the right boundary would be an additional condition for cutting off search on a particular line
    * For left bounds, I'm pretty sure you can just do a sub-function for calculating the default init_col
    * For right bound, this introduces another condition for checking stop. I think you could handle this calculation at the end of each line like stop_col currently is, and feed the right bounds to match_line. At least not adding significant additional checks per line.
  - This would support the Farsight labeling case for live/static jumping.

- [ ] For the main search function, there might be a way to do count with minimum where you add the first result to the struct, then replace instead of appending until you hit count. This is not a use case I need though

- [ ] The fold functions are mostly redundant code. But I don't think passing last_row and last_foldclosed to a predicate would be ergonomic.

- [ ] Scenario: Performing multi-win match on two windows with the same buffer, each displaying some overlapping portion of the buffer with the other
  - Currently: The full search would be run twice
  - What should happen: The code should identify that the same portion of the buffer is being shown in multiple windows and only match it once
  - Implementation issues:
    * Where to store the overlapping ranges
    * How to merge the overlapping ranges back into results
    * The code to resolve match ranges would need to be outlined. But, other than for this arbitrary thing, it makes no sense.

- [ ] search_single gets and stores row/col info for every result, even if min_one is false. This is unnecessary.
  - Unsure though how to section off this behavior without it getting bloated.

#### LOW:

- [ ] Is it possible to make the wrapper code to support the `c` flag?
- [ ] Is it possible to make the necessary wrapper code to support the `e` flag?
  - [ ] Encountered multiple edge cases here when trying to use this as a PUC Lua fallback

#### MAYBE:

- Compacting function:
  * Use case: Saving RAM
    + Counterpoint: Search results should be ephemeral
  * Problem: If you perform a sort on the results, that only changes the values in the idx list. This makes it impossible to unconditionally move down the underlying search data based on the order of the idxs
  * Bad solutions:
    + Re-sort the idxs in order
      + Combinatorially complex
    + Add a used boolean to results columns
      + More data to maintain
      + Another allocation
      + Add if checking to compacting
      + Counterpoint - Saves maintaining links between active_idxs and an idxs_ordered list.

* Temporarily set ignorecase and/or smartcase
  + Problem: Adds complexity when also considered with atom manipulation
    + Though this is improved by doing it all in a callback function
  + Problem: Bad if there's a hard error
    + Though search() is pcalled

- A canned iterator over the results to remove ones that are only on blank or all-whitespace lines
  * Unsure what the use case is though. Problem since this would be slow

- The fold filtering methods assume that results might not be ordered by position. If the results are filtered by position, it's faster to save last_row and last_foldclosed as individual integers. If the hash method creates a genuine performance issue, can revisit, but the current design is less fragile.

- If we create new results functions that actually return an iterator, add a setting to get_iters to return init - 1, to centralize the initial adjustment (since iter functions always increment before returning)

#### NON:

- Implementing any sort of wrapscan for match/search area. No use case + introduces numerous complexities around result sorting.

## Tab

#### MAYBE:

- Make the open_new_tab function more customizable. For now though I'd just like it to be a wrapper for getting a new tab open to a scratch buf with some sensible count handling

## Treesitter

#### MAYBE:

- Function to see if a line contains a TS node
  * Might be necessary for the annotator plugin, but would rather try to write around that, since finding a node type on a line would involve multiple layers of recursion.
    + Can probably just do annotator with string searching

## vcol

#### MAYBE:

- Many old functions sitting around from spec-ops.
- Use binary search. Because characters can contain multiple vcols, binary searching can fail or create additional logic in weird ways.
- For characters with variable widths, such as tabs or characters controlled by ambiwidth, strdisplaywidth uses the current window settings. In both of the use cases I can think of for this function (visual selection and quickfix), this is correct. If a use case comes up, some kind of context switching can be added.
