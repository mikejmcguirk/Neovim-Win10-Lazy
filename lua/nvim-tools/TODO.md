## General

#### TODO:

- [ ] Commenting guidelines:
  - [ ] Annotation comments:
    - Give an overview of how the function works for devs who want to know, broadly, what it does, without deep-diving into the details.
      * Example: The pos functions do not require deep explanation
      * Functions with longer annotation comments, therefore, imply that there is more you need to know
    - For functions that would be public facing, like config or search, provide a template for how they would be documented to end-users
  - [ ] Standard comments
    - Personal notes
    - Deep dive details
    - Why certain choices are made (search() needs a lot of these)

- [ ] The broader patterns described in the top level TODO doc all need to apply here
- [ ] I currently can actually name this nvim-tools, but check the big plugin collection repo before uploading

- [ ] Make sure everything has vim.validate in the params. It is easier for the user to remove than add them
  - Exceptions:
    - Validation functions (since they are, themselves, validators)

- [ ] Create a template minimal init that can be used for plugin debugging. The Neovim repo has an example they use for minimal plugin init, though that might be superceded with vim.pack released

- [ ] The module should be documented using my docgen
  - [ ] Make sure meta-table class documentation is correct
  - [ ] Docgen should be able to handle this. It does so for vim.filetype

- [ ] Test to see if win_call_maybe and buf_call_maybe are faster than running them unconditionally. If so, add them here and use them in all the internals.A
  - [ ] Test with different % of times where you need to context call vs not

- [ ] For compatibility, make sure any autocmd API usage or vim.keymap.sets or whatever use "buffer" semantics, and make a note to change those all to "buf" when v0.13 comes out

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

#### MID:

- [ ] get_indent should properly handle smartindent
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

#### MAYBE:

- Add a higher-level "open_buf_in" function that takes an integer|split|vsplit|tabnew opt. Trickier than it seems though because of how the opts/vars get moved around, and I don't have a concrete use case.
  - Additional issue, with rancher, the qf state management is intermingled with the buf opening/win handling. That is probably bad, but I don't want to do this kind of buffer opening in the abstract without knowing what the concrete issues to work around are. Are there certain returns we might need?

## Config

#### META:

- Be cautious about adding new automatic config delete conditions. If the user, say, wants to add BufDelete, they can make their own autocmd.

#### DEPS:

- [ ] Docgen. Because of the nature of how the config is designed, I need to know where the docgen lands in order to actually write the documentation.

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

#### FUTURE:

- Lots you could do with ranges, but will wait for use cases
  * Treesitter cmps might matter

## Search

#### META:

- Given the farsight case, the search results struct needs to be a subset of the targets struct.
- Do not handle farsight functions past cleaning of the results themselves
- I believe the _locator farsight module is the most up-to-date implementation, but it does not contain PUC compatibility

- Must address the following use cases
  * csearch movement (search single)
    + If a csearch result cannot be found at the specified count, noop
  * csearch highlighting
    + Includes edge trimming
  * bracket buffer navigation (search single)
    + Also includes going to the best fit count (See default `[m]m` behavior)
  + Live search (both ways)
  + Static search (entire visible buffer)
  + Whole buffer searches (extended)

- In the interest of accuracy, flexibility, and conceptual sanity:
  * The search module should only be concerned about getting the results and making sure they are accurate
    + Fixing LuaJIT results
    + Whatever PUC fixes are necessary
    + Fixing over-the-edge errors
    + Whatever else is in the previous code
  * Have another module that's used for result editing.
    + Fold filtering
    + Post-count resolution
      + If you want a minimum amount of results
  * This might cause some operations to be performed sub-optimally. Acceptable tradeoff IMO

* This function does not, in-and-of itself, support multi-window, but needs to support the underlying results manipulation that makes multi-window possible

#### TODO:

* [ ] Results iters
  * [ ] Sort
    - Use case: "Closeness" result sorting
    - Needs to take a predicate so it can handle cases like before/after or pythagorean distance
      * [ ] These are obvious functions to put into pos
        * I think before/after is already handled lt/gt
    - I think the predicate would then need to take all four values from both positions (eight total). Maybe make sorts that don't move all that data
  * [ ] Filter
    * [ ] From start/end
    * [ ] Stop on keep?
    * [ ] Max to filter
  * [ ] Map
  * [ ] Compact

- [ ] fold elimination
  * [ ] keep all
  * [ ] remove all
  * [ ] keep first (row == foldclosed())

- [ ] This should plugin to the nvim-tools config module to demo how it works

#### DOCUMENT:

- [ ] PUC-Lua compatibility is best-effort but not prioritized. LuaJIT recommended.
- [ ] Backwards searches to the end index can get "stuck" for reasons I'm unsure of. This is not an issue in JIT, where you can pull the ends from FFI, but it is relevant in PUC Lua, where you need an end search to fill in those values.
  - [ ] This breaks backwards wrapscan in PUC Lua if sending results to the struct, because PUC Lua needs to run a separate search for the end indices

- [ ] Why there is not an option to get multiple results with wrapscan
  - [ ] The backwards search issue described above with PUC Lua
  - [ ] Area search assumes that the results are in buffer order. I am not aware of a way to do wrapscan without breaking this assumption or introducing extra sorting
  - [ ] If wrapscan is done with backward search, it is slower. If it is done with forward search only, that introduces additional challenges with stitching/sorting the results
  - [ ] If you're trying to search upward for one result, and you have to wrapscan search from the start of the range, this is slow because you're looking for the last result
  - [ ] The exceptions this introduces to standard area searching would need to be addressed at runtime. Complicated!
    - [ ] Part of the value of this module is managing the quirks of the search() function. Handling wrapscan confuses this objective because of how much there would be to manage.

- [ ] The flags table cannot be passed in literally due to behavioral wrapping.
  - Results gathering/management
  - FFI usage/PUC-Lua compatibility
  - Search region handling

- [ ] Why the results iterators are the way they are
  - [ ] Individual list removes are slow, so we want to use filters so we can do bulk removals
  - [ ] Save boilerplate on aliasing the underlying refs

- [ ] Default csearch will no-op if the count is too high. Default bracket navigations will go to the best result. So you need to know what behavior you're targeting

#### MID:

- [ ] Merge overlapping results
  - Handles edge case with multi-line results

- [ ] For the main search function, there might be a way to do count with minimum where you add the first result to the struct, then replace instead of appending until you hit count. This is not a use case I need though

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

* Temporarily set ignorecase and/or smartcase
  + Problem: Adds complexity when also considered with atom manipulation
    + Though this is improved by doing it all in a callback function
  + Problem: Bad if there's a hard error
    + Though search() is pcalled

- A canned iterator over the results to remove ones that are only on blank or all-whitespace lines
  * Unsure what the use case is though. Problem since this would be slow

#### NON:

- Unless it's absolutely necessary, don't do the position hashing here. Goes against this being a minimal implementation.

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
