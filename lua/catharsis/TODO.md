## GENERAL

#### OBJECTIVES:

- [ ] Use the nvim-tools config module

#### TODO:

- [ ] Try to consolidate all of the ctx checking into common logic. Maybe pass an opts table?

- [ ] Plugin conversion checklist:
  - [ ] Change annotations to a plugin format
    - [ ] Remove "mjm" annotations
  - [ ] Move nvim-tools functions into a plugin-specific util module.
  - [ ] Verify nvim-tools isn't being required anywhere

- [ ] Archive lampshade
  - [ ] When catharsis is uploaded:
    - [ ] Push a commit with an archived message + update the README
    - [ ] Archive the repo

## DOCUMENT HIGHLIGHT

#### TODO:

- [ ] Come up with a name for this module (like lampshade)

#### SPEC:

- It might be useful to window-scope highlights.
  * Motivation:
    + If you have a buffer open in two windows, you can update the relevant document highlights in window a, and then when you return to window b the highlights for that cursor position are immediately available.
  * Problems:
    + If the buf version updates, you have to scan through every window-scoped result to check if it's relevant
    + Client requests do not come back with window ctx. For each buf key under requests, you would need to then store window-keyed requests. So when you get a request back from the server, you need to get its id, then iterate over pairs to find the buf request with that ID so you can extract the window information.

#### PR:

#### NON:

- Don't use CursorHold.
  - It's tied to UpdateTime, which varies per config.
  - CursorMoved is required to immediately remove stale highlights. Using CursorHold and CursorMoved together spams requests.

## DOCUMENT HL NAV

#### OBJECTIVES

- When a document highlight is showing, the user should be able to use bracket navigation to go to the previous/next highlight.

###### QUESTIONS

- If the user uses the bracket cmd and there is no document highlight present, what should happen? My instinct is that it should just show a "No highlights" message or a "Server does not support Document Highlight" message, because I don't see why it would be helpful for a user key press to inject itself into the module's event system.
  * The rough execution path would be something like - Check first to see if there is a highlight, if there is not one, then look at the reason why. There are a lot of reasons there might not be highlights and they have to be checked at runtime, so we want to avoid that path if we can. If the user wants to spam invalid requests, well, so it goes then.

#### DESIGN

###### RESEARCH

###### ARCHITECTING

- When the key is pressed, we need to know which of the cached highlights the cursor overlaps, so we can then iterate through the list
  * Dumbest solution - Do a binary search of the cached ranges against the cursor position
    + This is an ad hoc non-trivial time complexity solution
    + How does mfussennegger's overfly map do this?
    + Given that we have to check the cursor on CursorMoved anyway, is there not a way to save those results? get_ref_under_cursor does not identify which cached extmark we are overlapping, only that there is one.
      + This spooks me though because there could be goofy overlapping conditions involved.
      + Something to consider is that we check the cursor position for validity anyway when we generate the highlights, so you could use that cursor position as a starding point. We also do cache it anyway.
  * We need some kind of list tool where, given a particular list, start index, direction, and n items to move, you get the nth list item, wrapping around the list if necessary.
    + The simplest way to do this, probably, is to feed a list into the function, and then generate the args for wrapping add/wrapping sub.

###### PLANNING

###### TESTING

## LAMPSHADE

#### TODO:

- [ ] https://github.com/neovim/neovim/pull/38988
  - This PR changes the default code action command to be by position rather than by line
  - Lampshade needs to account for this
    * Could show a different color lamp based on whether or not the cursor is over the action on the line
    * Could also just only show a bulb when over a Code Action

## Rename

#### OBJECTIVES

- Experience
  * When performing a rename, an incremental, extmark-based preview will display
    + Show substitute highlighted text for the new name, ghost text for the old name
      + Stretch goal: Use inline space virtual text so the preview doesn't overlap with the old text
    + All teardown should be automatic when the user is done with rename input
    + The output should follow what the user does exactly
    + Folded lines should simply be ignored
    + The preview should show in all visible buffers in the current tabpage to which it applies
- Interface
  - should_prompt and new_name should be separate inputs
    * should_prompt == nil or should_prompt == true - prompt
    * should_prompt == false - rename immediately
    * If should_prompt and name == nil, use cword
    * If should_prompt and name == "", blank prompt
    * If no_prompt and name == "" or name == nil then exit
    * If no_prompt and name has content, send the request
  - By default, use the built-in "Substitute" and "Dimmed" highlight groups. Create "Dimmed" if it doesn't exist.
    * hl_new and hl_ghost should be provided as opts
  - opt to show preview before references come in (default true)
    * Would be substitute hl only based on cword
- Implementation
  * All communication with the LSP servers must use only the spec
  - Other than configuration, data must not be persisted between renames
  - prepareRename must be supported for servers that have it
    * If no_prompt and name, then just send it
    * Otherwise, do not open the prompt without running prepareRename
  - The original cursor position should be saved so that the request doesn't get stale when doing async
  - Only do the async implementation
  - Create our own namespace to avoid Neovim's defaults on this one
  - Use the VSCode multi-server selections strategy
    * If no rename providers at all, notify the user

#### NON-GOALS

- sync renaming
  * Maybe do this in the future if a use case comes up
- Callbacks for customizing behavior
  * This idea I actually like but it's inherently convoluted and I'd want to know the use case before exposing stuff
- Persistent config
  * Customization is spare enough that you can just pass opts into the Lua cmd, so you can just map what you want on Filetype
- Bespoke multi-server selection
  * You could have a preference opts list, but that's annoying to implement, and raises questions about why there aren't built-ins. Want to avoid the whole topic.

#### RESEARCH

- What are the technical details of how Neovim and inc-rename do what they do? What can we learn from them?

#### LEARNINGS

- For the rename result, I think we just want to use Neovim's built-in apply_text_edits function. We can try to get as deep as possible without going through every layer of validation, but at some point the logic is too complex. And it does all of the relevant handling or whatever.
- prepareRename handling:
  * null - Can't rename
  * Range only - Use that as your default
  * Range + placeholder - Use placeholder as default prompt
  * DefaultBehavior - Use cword

- VSCode references handling:
  * de-dupe
  * sort by file and position

https://github.com/smjonas/inc-rename.nvim/blob/main/lua/inc_rename/init.lua
https://github.com/nvimdev/lspsaga.nvim/blob/main/lua/lspsaga/rename/init.lua

#### TESTING/PLANNING

- Highlighting
  * You can build like, press a keymap and do highlighting + ghost text on cword without it actually doing anything. We want to have a working implementation of that so we know what the pitfalls are
  * We also want to see if virt text for adding spaces is viable
- Reference processing
  * Build out the reference processing pipeline independently
  * We need to time it then on bigger projects to see how long it takes. If it's too much, might need to do it with a coroutine
- Server scoring
  * This is a process basically independent of anything else
  * Should be in its own util file
- Rename/prepare renaming
  * We can just build a working re-implementation of rename that handles prepareRename the way I want it to be.

#### EVENT HANDLERS

- Create autocmds
  * I think you just always do this with clear autocmds
  * Watch the cmdline for changes and report them
  * Tear down events and state on leave
- Handle references coming in
  * Do necessary filtering and cleansing
  * Write them to some sort of state table
  * Push the refs to extmarks

#### Events

- On invocation
  * Setup the autocmds to track the cmdline contents
  * If a new name was provided, feed it to the cmd line
  * Request references from the server
- On references coming in
  *
- When the cmdline is left, those cmds need to be torn down

What data do you get if you try to run this on MD oxide? Both rename and references are per file which is weird.

what do you do if you don't have a client that supports references
print a message if no clients even support rename

#### TODO:

- [ ] Come up with a good module name.

#### MID:

- [ ] Generalize the concept by taking buf and ext_pos as opts. Because this would be able to be used in scripting though, more robust guards around prepareRename and rename request state would need to be added.
- [ ] Once cmdline is turned into a normal buffer, it should be possible to pull the cursor position out of it so it can be shown as part of the preview (just do it as a block cursor). Problem here - since this would be a new feature, would need a has statement to separate it out from the old code. Given significance of change, might be hard.

## PRS

- [ ] Add old_mode and new_mode to the vim.v.event annotation. vvars_extra.lua. Not auto-generated.
- [ ] Update the annotation for ev.data.method in LspNotify

## ISSUES

- [ ] Neovim should provide a way to distinguish between `null` and `nil` results. Currently they both just render as `result == nil`
