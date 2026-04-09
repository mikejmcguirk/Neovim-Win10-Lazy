## Design Philosophy

#### Goals:

- User intervention should never be required for proper formatting
- Edge cases should be discarded, rather than rendered incorrectly
- Configuration should not be required to produce professional results
- Support extended annotations such as @nodoc and @inlinedoc

#### Non-Goals:

- Supporting direct extraction of Lua data

## Overall

#### TODO:

handle inner todo here (ts to) and then rancher to do stuff

- [ ] The first/most tractable thing to do is probably massaging the config object architecture:
  - [ ] The shroedinger's type problem still persists because of the helptag object
    - This also makes the rendering more complex
  - [ ] The config objects are changed at differing points in the process in ways that are not particularly structured or consistent.
    - This makes what's there harder to reason about
    - This also makes adding new annotation support more difficult
    - This also makes it more difficult to add support for line numbering
  - [ ] I'm not sure if the full metatable scaffolding is necessary or wise, but we need to get the parser objects to act more like state machines.

- [ ] For parser obj data typing - Maybe make individualized types for fun, class, and so on, but have them inherit the main parser obj and overwrite with their own settings.

- [ ] I think that the way the default docgen handles module level results basically makes sense, because the M table is the standin for the whole module, so it should not be explicitly identified in the module. This includes sticking the desc into the briefs
  - But just tacking it to the end of the briefs puts the user back in the position of, well it goes where it goes. This gets back to why ordered insertion of elements matters
  - [ ] A smallish thing, but would rather not nil out an unordered hash list. But the actual solution exists in the broader context

- [ ] I'm not sure what the underlying mechanics of the md parsing are or what they are designed to accomplish in this context.
  - I don't know what the action items are, other than that md parsing issues cause different demo files I try to render to not work
  - But I don't want to do spot fixes because I don't understand the overall context
  - [ ] Is the md rendering in util useful for future markdown export plans?
  - [ ] Should hanging md tags in vimdoc always be allowed through? Or should it be contextual based on being in a brief or raw?

- [ ] Need to understand how the Lpeg grammar actually works
  - This unlocks being able to add/customize tag behavior

- [ ] Support manual ordering of elements
  - [ ] Line numbers need to attach to the parsed objects
    - I think using the i in the lines iter can help with this
  - [ ] It would be better if the objects were stored in line parse order to begin with
    - [ ] Maybe still do a safety sort
  - [ ] The ordering then needs to rely on the line numbering
    - [ ] Important though, in terms of how this is refactored, that the parsed objects do a lot of referencing each other for stuff like inline doc, and we can't break that
  - [ ] It would be better if automated briefs/classes/function ordering were still supported as an option. It is not mandatory
    - [ ] Relevant design issue: What do you do with custom modules?
      - A possibility would be to auto-sort the values within each module. But this then creates recursive ordering. Complicated!

- [ ] Go through the vimcats tags and prioritize their support

- [ ] Does the docgen have some kind of like, global scan for uniqueness in help tags?

- [ ] Most robust/customizable handling for mod names/tags and helptags in general
  - These issues are tied together because modules, classes, and functions generate tag names
  - [ ] Support the "mod" annotation
    - [ ] Always overwrites global settings
    - IMO, this addresses basically every bespoke use case
  - [ ] Support a "global heading" option
    - So for plugin devs, you would do something like "qf-rancher" as the global heading, which would then be automatically pre-pended to helptags
    - I think, regardless of how exactly mods are handled, this is still necessary, since asking the user to automatically write out every helptag is too much
  - [ ] You would then have a flag option for excluding auto-gen tags for certain things
    - [ ] Would need to be able to exclude
      - [ ] Filenames
      - [ ] Classes
      - [ ] Function
    - Idea: --exclude-tags lcf
      - Having a bunch of different flag options would bloat the top-level arg namespace
  - [ ] Do you allow a "noautotag" annotation to be attached to functions/classes?
    - On one hand, this feels like it could be confusing. On the other, it addresses the case where the auto-generated tags are mostly fine, but you need to remove one exception
  - [ ] Need to understand how the case should be handled where no autotag is specified but no manual tag is specified
    - [ ] Like, is it... allowed to make certain annotations without helptags? I don't know if there's a vimdoc spec that is opinionated on this issue, or if the treesitter/syntax parsers have requirements on this.
    - [ ] If it is allowed to have a vimdoc entry without a helptag, it should be possible to produce. If there is a dis-allowance for it in some spec, then the docgen should fallback to auto-tagging if the combination of the settings results in no tag

- [ ] Support table of contents
  - [ ] vimcats has a @toc tag for doing this yourself. Use that here
  - [ ] A global autogen toc flag should also exist
  - [ ] Setting/tag truth table:
    - [ ] global + toc > toc
    - [ ] global + notoc > global
    - [ ] noglobal + toc > toc
    - [ ] noglobal + notoc > notoc

- [ ] We need a solution for rendering rancher's keymaps and custom_cmds without having to directly extract the table data
  - [ ] A compromise could be to perform some kind of bespoke data extraction first, but that extraction has to be into something that the docgen can handle through a generalized process

- [ ] Where the docgen looks for "related" comments to a param/field needs to be consistent.
  - I would prefer to the side and up

- [ ] Support early-exiting modules like vimcats does

- [ ] Add the @raw tag

- [ ] Verify that stylua ignore is skipped
  - I think this docgen is where I saw the idea to begin with

- [ ] Make sure bullet rendering includes * and -. Maybe +
  - Basically, whatever markdown would do

- [ ] Look at the referenced docgens. Do they have ideas that are useful/valuable?

- [ ] Support the Markdown/README pipeline
  - panvimdoc does not help us because it does not turn Markdown into fully/properly formatted vimdoc.
  - Using panvimdoc to turn one README markdown file into vimdoc seems frivolous
  - And because it doesn't make formatted output, I'm not sure we can use it to back-convert md keymap/option info into Vimdoc.
    * And the ideas I have for how to deal with that relate more to the raw tag
  - Turning MD to vimdoc alongside normal .lua files also creates issues relating to how they are stitched together
    * Though this is a lesser concern
  - I am interested in building toward the longer-term goal of eventually just not using vimdoc.
  - The solution here then seems to be using the docgen to also be able to output markdown
  - [ ] For a file where we might only want to render to a certain point in markdown, have a @nomarkdown or @stopmarkdown tab
    - [ ] A similar tag should exist for vimdoc. No reason for it not to
  - [ ] I'm not sure yet if you need to just be able to use a @brief tag or something to produce Markdown translation, or if you can use the LuaCats grammar to parse markdown out of standard comments

- [ ] This needs to have tests
  - [ ] The original _spec files will hopefully be helpful
  - [ ] Add a no_output option for validation/debugging

- [ ] Neovim is under an Apache license, which has attribution requirements attached to it. Must be in the README for this separate release

#### MID:

- [ ] The indent adjusting in parse_doc_line on non-parse is confusing
  - I had a theory that this was padding for window display purposes, but this is not the case

- [ ] Global flags to control
  - [ ] Function rendering
  - [ ] Class rendering
    - Non-goal (move to that section when this overall block of TODO is done): Globally control inlinedoc (same with nodoc). So if you have class rendering disabled but a class is on inlinedoc, then the class will still render as inlinedoc inside the functions it's used
      - Likewise, if class rendering is enabled but function rendering is disabled, and a class is labeled as inlinedoc, then you don't see it
      - Flags for ignoreinlinedoc and/or ignorenodoc feel complicated to implement and create combinatorial complexity in behavior
  - [ ] Alias rendering

- [ ] Once this whole thing is much more robust, build cli around it.
- [ ] More robust arg parsing
- [ ] Add optional debug timers

#### LOW:

- [ ] Reading the files should be done async.
- [ ] Supporting Lua code literal class definitions in tables and self: functions
- [ ] Remove all nvim runner dependencies
- [ ] Supporting the divider tag. I guess it doesn't hurt anything, but IMO it's also low value

#### FUTURE:

- This is a task that wants to be written in a compiled language, since it involves so much text crunching
  * You could start getting really fancy with how the bytes are being read, rather than relying on higher level abstractions.

#### NON:

- Supporting extensibility
  * Creates complexity surface area
  * Would rather focus on expanding built-ins + robustness
- Supporting direct extraction of Lua data
  * Hard to do, conceptually, without custom hooks, which contradicts extensibility non-goal
  * The push should be to understand what the goals of custom extractions are, and how they can be addressed with new annotations
- This docgen inherits Neovim's removal of underline named functions. This is a useful convention, and no option will be provided to disable it.

## REFERENCES

* https://github.com/folke/snacks.nvim/blob/main/lua/snacks/meta/docs.lua
* panvimdoc
  + Though this doesn't solve the problem of how the function documentation gets into the md file
  + On the other hand, it does solve the problem of - Nvim's docs should just be in markdown
* https://github.com/lewis6991/gitsigns.nvim/blob/main/gen_help.lua
* https://github.com/lewis6991/async.nvim/blob/main/docgen.lua
* https://github.com/tjdevries/tree-sitter-lua - Maybe outdated, but useful
* https://github.com/stevearc/nvim_doc_tools
* https://github.com/folke/lazy.nvim/blob/main/lua/lazy/docs.lua
