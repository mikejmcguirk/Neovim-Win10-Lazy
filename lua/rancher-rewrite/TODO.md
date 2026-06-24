## CURRENT QFR BUGS

- [ ] The preview window hard errors when trying to load for an unloaded buffer
  - Need to trigger this again to get the full error info, but has something to do with the preview code trying to get buffer state before it's available
- [ ] The preview window no longer automatically closes when closing or exiting the qflist
  - [ ] Possibly related: The preview window does not close when the current list is cleared
- [ ] When running `<leader>qtf` on an empty qflist, get a hard error that sorts cannot be indexed due to being a nil value

## MOTIVATIONS

- Why a complete rewrite?
  * It seems easier to rewrite the code to work with Nvim-tools than it is to make nvim-tools fit into what's there
  * I want a cleaner Git history
  * I want to fundamentally re-think what's supposed to be in there
    + The grep plugin question sticks out
  * I want to fundamentally re-think the module design
    + This includes stuff like plugin mapping

- The current code inter-mingles and duplicates concerns among different modules. Concerns should be wholly discrete and unique between modules.

## OBJECTIVES

- Deliver a plugin focused on Qf/Loclist enhancement.
- The pieces need to be composable.
- The APIs need to be documented and simple
- The keymaps need to logically make sense

## DESIGN

#### QUESTIONS

- [ ] What to do with grep
  - Something like the "system" module will likely survive
  - A thin wrapper around rg/findstr/grep is confusing/hard to support/lame
  - On the other hand, not having Qgrep/Lgrep and so on feels feature incomplete since the Vim versions are tied to quickfix
  - Roughly feels like - Support rg and maybe findstr/grep out of the box. Don't worry about making the interface extensible
  - Figure out how to tie rancher to vim-grepper
- [ ] Do we need to make a separate grep plugin?
  - Feels dependent on what vim-grepper + others can do
- [ ] What to do with diagnostics
  - The built-in diagnostics module I think is more powerful than I originally realized
  - Just providing convenience wrappers for the built-ins is fine
- [ ] How much do we expose?
  - Something like the tools module is a good example because it provides a lot of generally useful interfaces, but I don't want them attached to a function contract, implicit or not.

#### RESEARCH

- [ ] Is it possible to create a qfbufnr without actually opening the list? This would allow for, say, opening the list as a float fresh.
- [ ] Need a universal method of parsing cmd args

#### TESTING

#### ARCHITECTING

--------------------

Problems:

Design Goals:

- Meta
  * It should continue to be the case that providing a src_win, in all cases, opens the location list, whereas a nil value opens the qflist.
  * Sub-tables should continue to be avoided in config
  * If customization is desired beyond the build-in string key options, a callback should always be provided rather than a bespoke table
  * Exposed functions should not be shims for underline functions. This creates complexity + behavioral inconsistency (have expounded upon this before)
    + The perf issues caused by referencing the config meta-table need to be handled at that level. Whether it's through some form of caching or an option to override validation. Fundamentally, the handling of config behavior needs to be centralized.
  * Any function that takes src_win needs to be able to take zero as a value. If the underlying function requires a specific window number, the bufnr should be resolved internally.
  * Any function that interfaces with a config option must take a local that can override it
  * Be more willing to use type aliases since they are extensible.
  * setqflist can take a nil action at least under some circumstances, so the wrappers around it need to be able to handle the same
  * Callbacks should be placed where they are logical.
  * Don't define module classes. This was an artifact of the old docgen
  * Remove defer require wherever possible

- APIs
  * Favor composability
    + I previously had too much fear about exposing "internal" functions. This resulted in the exposed APIs being overly on-rails and over-stuffed with options.
      + Example: It is obviously useful to the user to expose the function to filter diagnostics for top severity.
    * This allows for top-level APIs to not reveal all of their underlying customization if it introduces undue complexity, because the user can dig into the composable pieces if they want to refine further
      + Example: The top level diagnostic API might only take a string key for severity-level and another string key for "min" vs "only". If the user wants to create something more nuanced, the underlying code for diagnostic getting should be exposed.
  * Any API designed for keymaps/cmds needs to be simple, in order to avoid the current issue of having to construct complicated function args in that file.

- Module Design
  * Be willing to have many small modules
    + I had previously resisted over-eagerly breaking up modules to avoid pre-mature abstraction + undue fiddling. At this point, we have enough familiarity with the shape of the problem that we can be more confident here.
    + Example: The diagnostic module does two things. It collects diagnostics to send to the list, then prints to the list. This can be two modules, particularly because encapsulating the behaviors makes co-mingling them harder.

- Cmds
  * The "command apis" should at least be conceptually separate from the "main" APIs
    + The problem with exposing "q_diag_cmd" is that it implies the possibility the function is anything other than an arg parsing wrapper for the main diag API. But I also don't know a better way to allow the user to customize the user cmds.
  * At minimum, it needs to be possible to disable default cmd creation and use APIs to create your own. I think "off-rails" custom args are too complicated. Does leave the following possibilities:
    + Specify a custom prefix for cmds, so you could do "C" instead of "Q" and get "Cfilter", "Cgrep" and so on
    + Allow specifying customization per cmd

Underlying Functions (exhaustive):

- "Structured set" of list items.
  * Handle sort, title reuse, and what to do after set
  * IMO, this is one of the biggest opportunities to think more clearly about how lists are set and how the underlying functions should be composed

- Collect, filter, and sort diagnostics
- Format diagnostics for the list
- Clear/close? home diagnostics list if no diagnostics
- Based on the collected diagnostics, determine a home list name

- Parse cmdline args
- Add/remove cmds to a custom table
  * An attempt should be made to generalize this

- Based on some combination of inputs and options, calculate the new height of the list window
- Resize the list window
- Resize multiple list wins
- Close multiple list wins
- Close a qf/ll window
- Open a qf/ll window (including closing other list wins + integrated resizing)
- Emulate cwindow/lwindow
- Find one or many list wins
- See if a window is a location list origin
- Find a location list origin
- See if a window is able to contain a location list
- See if a win is a list win (qf or ll)
- Toggle the list win (including closing other list wins + integrated resizing)

- Resolve the alt_winnr (needs to be in nvim-tools)
- Check if the the current window is a qf/ll list
- Get how many items are in the current list
- Wrap a function in an option (mustly used for spk)
  * How does this handle nested pcalling?
  * Consider doing what vim._with does and handling the returns as a table, so the return type doesn't need to be any typed out ten times.
  * This should probably be a generalized fn in nvim-tools. Maybe you just do vim._with with more focused validation. Maybe you do it fully bespoke

- pwin close
- pbuf rm

- resolve case (vimcase, insensitive, sensitive, smart)
- Based on case and fixed-strings vs. regex, display to the user what will happen
  * This is also dependent on the underlying prg/function though. I believe that vim regex respects vim opts by default, and then you can override that with atoms. Whereas I think rg only looks at the flag args
- Get vregion (already in nvim-tools)
- Get trimmed vregion (should be in nvim-tools)
- Get input (should be in nvim-tools due to C-c handling)
- Based on pattern input and mode, use the provided pattern, prompt for one, or use the visual selection
  * I don't love how many concepts this wraps up, but it does seem to work, though the current function has to return a flag for if we're in visual mode (because you need to esc if so), which points to bad design
- wrapping add/wrapping sub (needs to be in nvim-tools)

- get the list item under the cursor
- Get list item at some idx
- Get item after wrapping math
  * This feels like it pushes down too much behavior
- get checked position
- protected set cursor
  * The rancher version of this gets checked position then sets the cursor. This might be an okay abstraction for nvim-tools, since you might want to validate a position for some other reason
- Convert qf position to cursor position
- Convert qf position to zero indexed, end exclusive
- Both of these conversions should be in nvim-tools
  * With a possible migration to vim.pos, but make the bespoke functions since that interface is still in development
- Convert vcol to byte bounds (add to nvim tools)
  * Double check if vcol2col is still based on screen col rather than local line
    + If so, implies that maybe my function naming should be "display_col" rather than vcol, since it might be a different thing
- Convert vcol to end col_
  * Might not be an nvim-tools thing, as this appears to be specifically related to converting the vcol value in a qfitem to the fin position
  * On the other hand, qf to cursor position is general enough to include, which would also take with it a bunch of the underlying pos code here
  * But since I'm not sure if this code is used in hot paths, we might be better off using vim.pos
- Check if a window is able to contain a location list

- open buffer
  * The rancher version of this is integrated with the item to open. The item behaviors should be decoupled so it just works like the nvim-tools version
- Get ordered wins from a tabpages (I think this is in nvim-tools)
- Create scratch buf
- Find a help win
- Split a window (needs to be in nvim-tools, since there's abstraction around origin, direction, and scratch buf generation)

Where does the clear list stack API go? It kinda feels like it has to go in the same place as clear stack because they share a map key

<!-- From the tools module. Unsure where these go yet -->
* Find a list with a title
* Resolve title re-use
  + Should this edit in place?
* what_ret_to_set

<!-- I have the new primitives, but am unsure where the structured functions go yet -->
- display chistory/lhistory
- goto chistory/lhistory
  * Basically, when you enter a count, does it go to [count] list or increment [count] list?
- structured clear stack

- sort a list
  * There is some validation in here that should be kept around
  * It would be really nice if you could have:
  `require("qf-rancher").sort()`
  `require("qf-rancher").sort.fname_asc()`
  Regardless, some solution is needed for the fact that we can't be putting every sort and filter predicate into the main init file. `require("qf-rancher.predicates").fname_asc()` is acceptable

* Open/close/manage a preview window
  + A lot of the create new win with buf logic here could be outlined and even put into nvim-tools.Including the logic for modifying the state of and layering treesitter into temp buffers.
  + I think what you roughly do here is, in nvim-tools, create a highly abstracted temp buf manager module. So you'd have cached bufs and the logic to deal with them. And then you could plug your preview logic or whatever else into it
    + Though temp bufs and preview bufs are a bit of a blending of concerns. You might just want to hold temp bufs are storage for some kind of data without activating treesitter
    + If there's no higher level module abstraction, still extract the primitives, including the state tracking
* Put the debounce logic into nvim-tools
  + Look at what ibl does and see if a meta-table is actually the more appropriate way to handle this

+ convert a list of text strings list items
* bulk edit a list before it's printed
  + Right now all we're changing is the type for help windows, but you should be able to do a list map here. I'm not sure if it even needs any special abstraction
* export system results to a list
  + I put this last because most of set_output_to_list should be outlined. The text line conversion functions can and should all be outlined (they might even be applicable to nvim-tools). The list editing and help win finding logic should be outlined, as should the buf open. And then you have the structured open logic described earlier.
  + There is also a higher level abstraction sitting in here. You could, in theory, make an option saying that if you create a new list and it has items, the first item should be opened. This would apply to grep and diagnostics. So in your structured open logic, you would have your opts to open the list, and then your opts to auto open the list item.
  + This all essentially turns the system module into a wrapper for other things, but I'm basically okay with that.

- resolve boolean opt
- validate types

- Open a specific list idx
- Open a list idx based on wrapping count
  * The list opening is one of the most important things to abstract out, because the nav cmds and ftplugin file both rely on this logic, and it should not be created in duplicate
- Wrap vim qf/ll cmds (file and last/rewind)

- Run checkhealth

- Grep
  * This is going to be abstracted into a new plugin
    + Roughly, the new plugin will be what the grep module is now
    + In the rancher context, it needs to return a string[] for system to run
      + The new plugin though should be built around the idea that it can be integrated into anything, so its APIs should be fairly broad
    + Because rancher and the new grep plugin will share code, this prompts more nvim-tools additions. This also prompts more careful thinking about how to scope concerns
      + The grep plugin would just use copen/lopen + history. But both could probably share the buf detection and and opening code
      + If you want to use both plugins, I would build my assumptions around the idea that you are integrating grep into rancher, rather than the other way around. Though I guess there's nor reason the other direction can't be possible
      + Of particular interest is the visual mode pattern matching. There's no reason both plugins couldn't do this, but when using the integration, which one handles it? Does it depend on which API you use?
    + This plugin should also handle search() for local buffers
    + References for new plugin:
      + vim-grepper
      + nvim-spectre
      + brooth/far.vim
      + chrisgrieser/nvim-rip-substitute
      + roobert/search-replace.nvim
      + grug-far
      + ctrlsf.vim
  * In the rancher alone case, only ripgrep will be supported.
    + A lot of the sub-modules in the current grep module have already been broken out.
    + Like with sort, the actual setting up of the grepping should be its own module (which it somewhat is in this case), with the location funcs in a discoverable file
      + Some of the location funcs can probably go into nvim-tools
  * Stashing for future reference: https://github.com/Anadian/regex-translator/tree/main

+ filter keep a list
+ filter remove a list
  + Maybe the most challenging module because of how inter-mingled everything is
  + All of the thoughts about about module structure apply doubly so here because of this problem
  + break filter_keep and filter_remove into separate functions to help

+ Delete on qf line
+ Delete multiple qf lines
  + For whatever reason, this function contains a lot of stuff like location list detection and vrange 4 that should be outlined
  + This function also contains a manual check of the new_idx against the length of the list. Shouldn't set_list just do this if the idx key is present?
+ save orphaned lists
+ Check empty noname buf (nvim-tools has this)
+ This module contains multiple finding loops that need to be abstracted
  + The iterators themselves can be abstracted. Based on input settings, you can build the starting position, predicate, and direction before entering hot code.
    + Is skip_winnr generalizeable or does that have to be in the predicate? Probably the predicate
  + Likewise, the list of wins to iter over can be abstracted. You have the get ordered wins in tab code above. So you can use that to pull your list to iterate over.
    + A re-review of valid qf-wins is required. They would have to be focusable and a valid buftype, right?
      + Appears to be the case, based on is_valid_dest_win
      + Confusing though because it checks if the buf is a noname. Why?
  + We also need to consider making a concession to sanity/simplicity and doing a pre-filter of invalid wins before iterating. This might even be faster any way since it chunks out the branching logic.
+ Another example of create scratch buf here
  + These aren't all different, are they? I am starting to wonder if, in the nvim-tools function, you do a baseline set of options like noundofile and noswap file and then use a callback to layer in other stuff you need. For example, modifiable is situation dependent
+ Get win_id from vcount (maybe put into nvim-tools)
+ mentioned previously but relevant again - There needs to be an nvim-tools abstracted set of tools for splitting wins, due to the abstractions
+ Deconstruct switchbuf
+ Get tabnr and winnr from win id (nvim-tools)
+ Find valid help window (separate qf and ll logic)
  + Re-review the core logic
+ Find "" buffer (qf and ll)
+ I am hoping that the buffer finding logic can be pared down after more of it is properly abstracted
+ Note that, just as the nav logic is relevant to here, this logic is relevant to nav, as you might find yourself doing said navigation without a valid window to open into
+ Open a list item in a new tab
  + A lot of opportunity for nvim-tools extraction. Applies to harpoon as well
+ Open a list item (qf and ll)
  + Goes back to the buffer open discussion above

+ Set mappings and settings on filetype
  + This needs to be able to pull keymap prefixes from config

NEW MODULE DESIGN:
<!-- I'm not sure to what extent yet I want to layer other TODO items into the module tree, so I'm just adding as I feel is relevant here. Will either consolidate or piece this out later -->

Note:
- At least to start, the idea here is to build up the list of functions that the APIs are then composed out of. We do not, at this juncture, and maybe not for a while, need to determine what the APIs actually are
- I don't want to think overly deeply about the technicalities of the interfaces here. Don't want to find myself whiteboard programming.

- LIST EDITING

  * Functions related to the creation, clearing, and editing of individual lists within the stack
    + An unfortunate leakage here is setlist("f")
  * The sanest way to do this is probably using the tools module then renaming it when the time comes
  * The setlist functions need to be able to handle nil actions
  * Inline the handling of the -1 case into get_result so it's less confusing
  * Document the resolution numbers somewhere. -1 bad, 0 good after stack delete, 1+ good, with specified destination list
  * If the qflist is closed, should deletes just happen silently? Should they tell you than happened? Open the list first? Prompt?

  * FUNCTIONS:
    + Resolve input list_nr
    + Resolve result list_nr
    + Thin src_win setlist wrapper (nvim-tools)
      + Needs to handle both valid forms of the argument
    + Thin src_win getlist wrapper (nvim-tools)
    + Structured setlist
      + Handles what it currently does
    + Clear list
      + Useful due to proper metadata handling
    + Structured Getlist
      + Gives you nr resolution

- STACK TOOLS

  * This is a new module to contain primitives for stack navigation and modification
    + This means goto count history is not present here
    + Even though display full history is the same cmd as goto history, we break it into a different primitive since the result is so different
  + I'm not sure if there are enough total functions here to justify breaking navigation and editing into two modules. Break up though if this ends up being the case

  + FUNCTIONS:
    + get_stack
      + Return an ordered list of all lists in the stack
    + set_stack
      + Overwrite a stack with an ordered list of lists
    + display_full history
      + history cmd with nil count (rancher behavior)
    + goto_history
      + history cmd with >0 count (rancher behavior)
    + Clear stack
      + Very thin wrapper that just handles src_win and location list validation

---

###### Other:

- [ ] An opt to control if list naming is simple (just diagnostics, or just the grep cmd) or complex (individual diagnostic scopes, grep paths)
- [ ] A keymap should exist that opens the currently selected list item in the current, non-qf window (rather than having to go to the window to select it)
- [ ] Remove any instances of doing while idle
  - Introduces significant complexity surface area for no gain (since idle doesn't actually mean idle user state)
- [ ] Port in the nvim-tools open_buf code
* [ ] Does this affect how I handle help windows? - https://github.com/neovim/neovim/commit/6f12663de56b5c363e5abefc3ddbe1fd3bbc7989
* [ ] Undo any changes I made to use full option names. This caused a bunch of pain I did not expect, and will instead be resolved by improved grep scripts
* [ ] Remove any instances of public interfaces being validation wrappers for private interfaces that are otherwise the same
  * Separating validation and resolution of input vars is possible, but complex
  * Creates complexity surface area for inconsistency in behavior
  * The possible failure points between the internal and public interfaces need to be the same
  * [ ] Document this reasoning in CONTRIBUTING

#### LOW:

- Allow the user to re-generate default Plugs/Maps/Cmds based on updated option keys
  * Because old maps could have been created with different option keys, this function would need to search for old maps to delete under broad criteria, being destructive to user-created maps
    + Perhaps support a no_del option, though I'm not sure what the impact would be of leaving the old keymaps around
      + If you did this, you would still create the new mappings unconditionally, as checking with maparg adds a second crossing of the Lua bridge

#### FUTURE:

- If an issue comes up that demands it, add a style section to CONTRIBUTING

## Window

#### TODO:

- [ ] I'm not sure how much of this is documentation vs. code, but you need to be able to use the window function to open items to the list in other applications
  - [ ] fzf-lua: This feels like documenting a config snippet. Though it's worth checking to see if fzf-lua provides a config option to wire in external behavior for sendtoqflist.
    - [ ] If fzf-lua does provide that option, it's still probably better to provide a config snippet. You would have, I would think, an "Integrating with Other Plugins" section of the code with snippets to just copy and paste.
  - [ ] Nvim LSP results opening
    - [ ] Because users might have their own custom callbacks, these would be config snippets
      - [ ] You probably only need to provide one example for on_list
      - [ ] But there's the one LSP function that does not use the standard on_list format. Needs to be documented separately.

## Grep

#### TODO:

- [ ] Are these relevant?:
  * [ ] https://github.com/folke/snacks.nvim/commit/b2cb00ef7d12da7f2d6e0684c43e2965896309dd
  * [ ] https://github.com/folke/snacks.nvim/commit/a049339328e2599ad6e85a69fa034ac501e921b2

* [ ] Make sure that any grep scripts/wrappers support "whole word" pre-built grepping.
  * Maybe support an "after-pattern" callback that applies a canned transformation to the pattern
    + Tough though because you have to send variables related to regex and case state
  * This is a good argument for improving cmd support, as I could much more easily do a keymap like `<cmd>Qgrep regex /\\<lt>\\<gt><left><left>` to get the result I'm looking for

## Preview

#### TODO:

#### MID:

- [ ] What does the drop cmd let you do? Should I implement support for it like bqf has?
  - The docs suggest that debuggers might want to use it, which makes sense in the qf context. But I don't understand the logical flow the doc is describing.

#### LOW:

- [ ] Implement preview window scrolling
  - This is on the roadmap because it's such a standard feature, but IMO the value/effort ratio is bad.

#### MAYBE:

- bqf has a zp map to toggle the preview window between normal and max size
  * Currently bad value/effort ratio. I'm not sure what the use case is.

## Ftplugin

#### TODO:

- [ ] Map `v`/`<C-v>` to either a or i
  + [ ] i
    + Pros: Good finger motion, good mnemonic
    + Cons: Same finger as k
  + [ ] a
    + Pros: Good finger motion
    + Cons: Bad mnemonic, bad ctrl fingering
  + [ ] Look into other ack style qf mappings to see if a and i have historical uses that I would be overlapping
  + [ ] I'm not sure which demerit is worse. `<C-a>` is terrible, but less common. i being on the same key as k does not feel bad, but it is also slow, and more common.
  + [ ] This muddies the "ack style" branding of the ftplugin maps
    + bqf does not mention this in their README. I don't see why I would need to do the same
    + Note the historical roots in the docs
      + vim-qf is the plugin I've seen that explicitly describes the mappings as ack.vim styled, but I'm not sure if it's the first plugin to actually use the convention.

- [ ] Should do_zzze not affect opening entries with oO?
  - Pros:
    * Opening an entry with o when it's on the screen needlessly introduces visual noise
    * Configuring this behavior manually would be a pain, since you would need to disable zzze globally, then re-enable it in a callback for most functions
  - Cons:
    * This is confusing if you're not intuitively in sync with the reasoning, and verbose to document
      + Made worse by the fact that `<C-o>` should not be affected by this idea, because you might use open-nofocus to set up diff windows, so the scroll positions need to be the same
    * Would be obnoxious to code/maintain
      + Worse because this change might propagate across modules, meaning you need to define it as a piece of util logic you bring in before running open_buf or an ex_cmd
      + The logic for this would need to account for fill lines, adding additional complication

- [ ] Provide a post-open hook the user can use to add custom behavior
  - Do not handle fdo in here, as it might need to be handled earlier with window context

-------------

- [ ] rancher
  - [ ] Relevant?: https://github.com/neovim/neovim/commit/a5d4b4e0fc438281bd50b4b30bc5d31ac4b208d9
  - [ ] qf positions are one indexed, end exclusive (see lhelpgrep results). The preview and diagnostic conversion code needs to account for this (same with grep perhaps)
  - [ ] Bracket navigation should not show error codes, since we are not representing them as errors. They should just show something like "No Errors" in Normal text.
  - [ ] I am concerned about the level of bespoke logic used for list opening. Can we not just build wrapper code around cc? Can it not just be nvim_win_call?
    - Obvious problem comes about when thinking about zzze.
    - I'm not sure if cc/ll auto-focus the opened window
    - Can look at how other plugins do it
  - [ ] Use updated qf_to_vex function for positions
  - [ ] https://github.com/ten3roberts/qf.nvim
    - [ ] Farm + Add to credits/references
  - [ ] The fallback preview buf has bufhidden set to wipe even though it's meant to persist. Should be hidden
  - [ ] I might have this noted already, but for cmd customization, store customized cmds in a separate table from the built-ins
  - [ ] Why is rging helptags slower than lhelpgrep? Aren't they both external grep?
    - [ ] My grep probably needs to take up unloaded lazy help files

  - [ ] Some kind of "grep dir" function that doesn't require setting cwd

  - [ ] When making new lists, there should be an attempt to re-use blank lists
  - [ ] Add an fzf-lua integration for sendtoqflist
    - Can be either a doc snippet or actual Lua code
    - [ ] Should be based on a re-usable title if possible

  - With rg only
    - Would keep the system module very general/flexible so it can accept a variety of external plugins

  - [ ] Instead of the current config for spk in the window functions, provide it as an option override and set the default config to topline as per the meta doc for plugs above
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
  - [ ] Add a "bcd" grep. For now, this can pull based on bufname and notify the user if that's not available
    - Necessary for being able to grep sub-folders without noise from the larger project

- [ ] grep plugin
  - [ ] Notes here are currently in the rancher docs. Outline back to my files

- [ ] Make a more useful rancher + grep plugin integration
- [ ] annotator
- [ ] text tools

## Extended Writeups

#### API Problems

  * This is partially caused by the module confusion above
    + This is best embodied by the grep module taking tables for what, grep options, and system options

  * Requiring function args for sort/grep locations was a mistake. It makes the APIs less convenient to work with
    + This also contributes to the feature surfacing issue below, where you cannot see, at a glance, say, what built-in sort functions are available. Even if the sort module were properly documented, it causes a lot of scrolling.

  * Both from an internal and external perspective, the pre-built options are not properly surfaced or distinguished from where the user can customize
    + The grep and sort libs are not documented

  * The diagnostic API contains an example of something that exists in multiple points in this plugin, but I'm not sure how to broadly define:
    + For filtering diagnostics, it makes fields available for diagnostic.GetOpts as well as a boolean for filtering top severity. This creates an imbalance where most of the question of "what diagnostics am I going to display?" is handled in one key, but then one other key performs a conceptually simple but practically significant change.
      + The correct solution would be to either use multiple keys to feed a getter sub-function, or use one string|fun() key for choosing diagnostics, making the filter for top function public for any callbacks (the better choice, since it's more flexible).

  * The APIs also contain multiple implicit, undocumented behaviors
    + Example: src_win in diagnostics controls if you get buffer or global scoped diagnostics
      + On one hand, this is obviously logical. On the other hand, say the user is working in a project with nested project/LSP scopes. The user might want to use the src_win to get the buffer, then use the bufnr to get the relevant project local scopes and print that to the location list. This is currently not possible.
        + In effect, and this is not the only place this is true, the APIs introduce a lot of business while still being rather rigid.
        + One counterpoint: Hard constraints should still exist where they are logical. If a src_win is provided, that should always result in opening the location list.
    + The solution here is partially documentation, partially more clear params

#### Keymap Problems

- I've made various comments alluding to different parts of this, but the current design of the keymaps is inflexible and logically inconsistent
  * `<leader>qtf` sorts in place, whereas `<leader>qin` creates a new or replaced list of diagnostics. If you map qtF to export sort to new list, that creates an inconsistency with diagnostics and grep. qTf - same thing.
    + This picks at a sub issue of how you select action + rancher's layered in behavior. I think, on a high-level, this is fine, but needs a better interface
  * Current main maps:
    + grep - new/title reuse
    + diag - new/title reuse
    + sort - in place
    + filter - in place
  * My current solution is to use lowercase for the preferred mapping, then always map uppercase, ctrl, and alt to new, in place, and merge. You would then have options for creating extended maps and extended plugs
  * The defaults take too long too load
    + Worse, this is with them being lazy loaded, which should not be done
