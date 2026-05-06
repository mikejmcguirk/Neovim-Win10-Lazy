## General

#### TODO:

- [ ] I have an old note about object building that mentions indent handling. If there's indent code in the build objs, outline
- [ ] Fix data-typing nags
- [ ] Are we okay with how DocItem is done? It feels like it's hiding some kind of subtle potential bug
- [ ] The big clump function in parser_obj needs to be moved to the metatable model
  - Feels like the time/place to tag things as functions

- [ ] See if the "builder" obj can be removed. I don't understand why the parser object can't properly manage state
- [ ] Add code to ignore stylua tags
  - I think the core's docgen does this. If not, I have to imagine that every one does

- [ ] The rendering code still lacks structure. There's no coherent theme for "when" things happen (turning obj data into strings vs. turning them into lists vs. formatting them)
  - Do we think of it as a kind of recursion?

- [ ] Fix the wrap function
  - Do now because the stuff below needs to be able to make more consistent assumptions about formatting
  - NOTE: Tabs need to be treated as eight spaces since vimdoc ts=8
  - The idea is basically like, you pre-figure out based on indents where the line is supposed to be, then pull the string subs
    * When you hit a marker, go backwards for first non-white
    * Keep in mind the thing in vim.trim. Match is slow or something
  - We want to be not clobbering inlined whitespace

- [ ] There's a note out there somewhere about how class descriptions above are discarded if one below is found
- [ ] This feeds into a larger issue - Right now descriptions seem to be pulled correctly automagically, but IMO this is bad and will break at some point
  - [ ] Class descriptions need to be above and to the side
  - [ ] Function param descriptions need to be to the side and below

- [ ] I don't know if it's necessary or a good idea to build this out fully now, but we want to make sure some of the skeleton is out there to handle warnings. Because we want to be able to write them to a log of the user wants
  - Related to this, I think I threw out all the logging stuff a bit prematurely. The overriding problem is that basically everything in the docgen is a hot path, but like, are there transition points where it makes sense and doesn't create too many IO hits?

- [ ] In part for performance reasons, in part for data hygiene reasons, if something is marked @nodoc building needs to be skipped so we can just get to the end of the current "thing" and discard it
  - Something I'm weirdly unclear about is like, I guess @nodoc works no matter where in the annotation block it is, which feels weird.
  - [ ] @nodoc should only trigger if it's the first thing in the annotation block, or at the very least the first tag. If not, it should be a warning

- [ ] @deprecated needs to be treated here like @nodoc (avoid needing redundant annotations)

- [ ] Need a better/more coherent way of managing how classes are referenced.
  - We need to hold a table of class references by name for inlinedoc purposes
  - I would think/hope that you can just put the classes in a master object list and hold the name ref for inlinedoc only and be done with it

- [ ] Can inlinedoc/nodoc be turned into a "docstyle" var?

  - [ ] Can the various nil checks be changed into something else? Unsure how to do that though since Nil is a clear way to say this is not here

- [ ] Handle core updates:
  - [ ] Affects class rendering: https://github.com/neovim/neovim/pull/39078
  - [ ] Sorted class fields: https://github.com/neovim/neovim/commit/033efbbd32fad882da67c0a1f658d1c12a8d515e
    - https://github.com/neovim/neovim/pull/39427
  - [ ] Nested inlinedoc fix: https://github.com/neovim/neovim/commit/825bfba789d924ab2f33b3e87814750863ff4f02
  - [ ] https://github.com/neovim/neovim/commit/7ed5609439ba83d75e972beb859245d998df09ea - Does this affect if a trailing newline needs to be added at the end of the str when parsing LuaCATs to MD?
  - [ ] https://github.com/neovim/neovim/commit/d7ef55e8817627af0f25dc2bb9ed9927d0049d6a - Additional generics handling
    - Might not be relevant for now though since this is for emmylua. If not, throw into FUTURE because I get the impression the long term push is to migrate there

- [ ] Delete docgen_00.lua at some point. Want to hold onto it though in case it has old code I want to use, like for warning emission

- [ ] The remaining TODO comments in the rest of the docgen are placed reasonably. Just work through them without moving here.

- [ ] Create actual docgen strategic plan
  - Motivation:
    * The LuaCATs > Vimdoc script needs to handle module building/tag construction/file stitching in line with a broader strategy
    * The overall strategy might dictate which LuaCATs tags are needed (custom or otherwise)
  - Problems:
    * README construction
      + It simply cannot be the case that documentation is written in duplicate between the README and Vimdoc. Maintaining this is a time suck and creates potential for mistakes
      + Writing MD in LuaCATs is bad because it can't line wrap
      + How do you integrate README content into vimdoc toc?
    * Extracting docs from Lua code
      + If I define keymaps or cmds, I need to be able to extract that into vimdoc or MD
      + Additional layer: Right now I am assuming that my `/plugin` file will require the plugin's init.lua file, which will then not eagerly require additional files. I am fine with this tradeoff. I do not want to be putting keymaps into init.lua or requiring additional files. Making plugin.lua return an M table feels hacky
  - What Is Documentation:
    * Seems like trivial question but is important
    * README should answer basic questions about what the plugin does and show visuals. I should know if I want to install the plugin from reading it
    * Something I have done a lot but is a bad idea is using README to build config
      + Nonetheless, I doubt I'm the only one who does this. So the README should include like, the bootstrap config
      + However, and this should be certainly advertised the README, my goal with plugins is to have sensible defaults
      + Should also include credits/attributions
    * The docs should work as narrative
      + The first thing I need to look at is the install directions to verify I did it correctly
      + The next thing I need to see is the config so I know what settings there are and if I want to change them
        + A bit tough because the config module holds the API info. You could actually require it and pull its default config but that feels silly
        + Being able to actually see a Lua table plopped into the vimdoc is insanely useful.
          + I'm torn though because we do have the class annotations to use, and they are relevant for stuff like editing config. Maybe you do a see tag on the functions that use it and the see tag goes to the Lua table doc
      + I also want to see Highlight groups early. This is one of the first things I typically want to change
      + I then want to see what the keymaps/plug maps/cmds are. Basically getting the baseline level interface
        + Rancher is a bit of a special snowflake though because it's broken out by module. Though that might be changed
      + Then I want to see the APIs
      + Then if we have stuff like autocmds I want to see that
      + One thing that's at best a necessary evil is when plugins talk a lot about their own dialect they have set up. This is stuff like the plugin's internal datatypes. Or very high level but also technical descriptions of things the plugin does. I know I have it within myself to have the tendency to do this and should actively avoid it
  - Research:
    * Stevearc doctools:
      + In terms of the overall approach it feels like I have to go with, his stuff seems like the best fit, as it's built to handle stitching and extraction from multiple sources
      * https://github.com/stevearc/nvim_doc_tools
    * img-clip looks like it does interesting stuff with markdown/vimdoc
    * panvimdoc
    * Go through all the plugins I have installed for ideas
    * https://github.com/lewis6991/async.nvim/blob/main/docgen.lua
    * https://github.com/tjdevries/tree-sitter-lua - Maybe outdated, but useful
  - High-Level Reasoning:
    * Hard Requirements:
      + Do not extract LuaCATs into markdown with the expectation of formatting
      + Need to be able to write out the below in pure Lua and get in the docs, somehow
        + Keymaps
        + Cmds
        + Options tables
          + This in particular might be a less hard requirement because you can get the @class vimdoc
      + Need consistent method to document installation
        + Relevant because it needs to be in both README and vimdoc
        + Relevant because it fits into lazy.nvim documentation - Does lazy.nvim's "opts" key pick up my config function? Should it?
    * Likely Requirements:
      + "Data" files:
        + Basically do like `eval.lua`
        + The field names need to be hashkeys for maintainability/extensibility
        + Perhaps add an "extended desc" field. If so, this needs to be "output ambiguous". You can format it into LuaCATs or MD or whatever, but it should not encode those expectations
          + Slightly tricky because of cross-referencing. The keymap docs should not contain extensive notes (the details should be documented in the APIs), but you need to be able to add "See" notes and tag links to the relevant functions.
        + It is fine if the data files create generated files that are then used by the vimdocgen. But files should not be created that are only for docgen then deleted. Wasteful file IO.
  - Ideas:
    * Data files
      + Motivation: Don't want to require more files in `/plugin`
      + Layers:
        + The files:
          + Use hash keys for field names. More maintainable/extensible
          + Things to handle:
            + keymaps
            + cmds
            + autocmds?
            + config?
        + Extraction:
          + Needs to be able to extract to lua and markdown.
            + For Lua, this includes both the actual code as well as the LuaCATs
              + The extracted files would then be used for docgen. Ordering issues need to be handled in the data/file/stitching design stage. We cannot be in the business of creating temp files for docs. Too slow. And we cannot be in the business of creating markdown to then create vimdoc unless in an absolutely necessary case like the formatted README flavor text. Too many steps
            + For Markdown, this will either be tables or some other templated format
          + The extractors need to output in `string[]` or something general so that different stitchers can pick them up.
        + Stitcher:
          + Very high level. Just put files together. Should not need or be able to have awareness of the underlying content
          + Relevant for Lua data files and markdown
          + Should be able to take as input a mix and match of files and lines (so, for data file outputs, you don't have to do IO to write them only to be picked up by the stitcher again)
          + Obvious, but, the output files should have very visible notices saying not to manually edit
        + Other files:
          + It would be helpful to have a linter along with this where, if a generator source changes but not the expected output, it means you need to re-generate. If an output file changes but not the generator, it means the output was edited manually. Bad.
        + General:
          + Put in `lua/plugin_name/scripts`. Seems standard. Should also allow all intermediary + generated files to be picked up by Lua_Ls
          + Standard "plugin_source" file that's stitched in first
          + Obvious, but: Can't define LuaCATs types in these files or else they'll show as duplicated when editing
          + Use Nvim as the runner for these scripts
          + Add a MakeFile to structure running them
            + This seems the most professional/platform agnostic. Worthwhile skill to learn
            + This also lets you do stuff too like structuring stylua runs
            + Could also build this into CI
          + An idea that I hate but that might be inevitable is that you have a readme_template file with some of the stuff like the intro and high level info, and you make a stitch of that with data file extractions to to make `README.md`. And then use panvimdoc to take the intro segment and convert it into Vimdoc. But that creates more questions with how the doc pieces are stitched together, since now we're trying to put LuaCATs and panvimdoc results together.
          * It should be possible to handle config using the class table definitions + desc text + briefs from the init module (for the config metatable).
            + If using pure g:vars for documentation then you can just use @mod and @brief tags. If that's too cumbersome, well, then, probably should be a config class module.

- [ ] After here is when the business of creating modules and toc and such really kicks in. We need some kind of actual strategy for handling how README and markdown and handled, and the docgen needs to be able to handle it.

- [ ] The future items below require building out logic for when module headings are created. The vimdoc treesitter page has a link to the vimdoc spec. Read and familiarize.

- [ ] I want to be able to, after parsing, be able to traverse the created objects and create/render the TOC before rendering. The data should be available to do this
  - This also implies that a lot of info like helptags should be ready to go before rendering, which might impact a lot of the stuff below

- [ ] Conceptually, when are modules auto-created?
  - A file's docs need to start with a module
  - Should nothing be able to be added to the list until we have a module? Just hold a boolean flag?
  - If we start making something that's not a module and there's no module, do we then auto-create?

- [ ] Support manual ordering of elements
  - The fundamental idea is to traverse each file in order, add the objects in the order they are seen, and render the objects in the order they are seen
    - Not adding any sort of sorting opt for now. Might even put it as a NON. This thing is just too complicated
  - [ ] The @mod tag needs to be supported in the near future.
    - This means, at this step, we need to make sure that the way the docgen is read and processed fits into it.
    - [ ] So, when we start a new file, we should use that information as the basis to create a mod parser object.
    - [ ] The renderer then needs to hit the mod object and build the top level section info, rather than doing it as some kind of bundling
    - IMO it is risky/bad to store the modules/sections as containers because it introduces recursive logic.
      * This is a broader point, but you have class names, I want to add something to track help tags, and we might need some kind of module level visibility. I am directionally fine with creating some sort of "meta" struct that holds "collection of things that are in the docgen" because
        + Data only really goes in
        + It's not used as the basis for complex logic
      * While it would kinda just hang out there, it would also eliminate scanning and recursion, which are both good
      * Unlike module nesting or whatever, a meta dump could be modified at one layer (basically, again, not recursion)
  - [ ] An implication of all of this is that files are processed in the order they are inputted. This is obvious by implication but needs to be an explicitly documented/guaranteed thing

- [ ] Need to prevent duplicate help tags from being created.
  - Most obvious/easy/blunt fix is to keep a map of added tags and reject tags that are duplicates
    - Dumb though because different files might have their own "new" functions
  - More nuanced approach is to build helptags by project name (input var), module, then specific object
    * You would want a list of module names to prevent duplicate @mod tags within a file. This gets squicky though because now we're introducing weird hidden hierarchical reasoning
  - Since we are building the ordered file construction under the assumption that it uses the future mod construct, this issue needs to be solved before the @mod and @tag annotations are introduced, so their results can just plug in
  - [ ] This all means that a close-to-finalized version of the user input needs to be gathered now
    - This also needs some kind of fallback for how to get the "project" name. The core's docgen has the "Nvim" semantics baked in everywhere because of course it would

- [ ] Need to understand how the Lpeg grammar actually works
  - This unlocks being able to add/customize tag behavior

- [ ] Go through the vimcats tags and prioritize their support
  - [ ] Anything in the actual official LuaCATs grammar that is not supported should be
    - Though, I'm not sure how totally feasible this actually is
  - [ ] @mod
  - [ ] @tag
  - [ ] @export

- [ ] Support table of contents
  - The simplest way to do this is just to traverse the parsed objects and pull it together automatically
    * [ ] There should most definitely be a cli flag to turn off auto toc
  - It's like, not conceptually bad per se to support a manual toc annotation, because basically the parser obj could just pick up the pieces and you could use the same rendering code that auto-toc does. If the user puts it somewhere that's dumb that's not my problem (though maybe there's a vimdoc spec issue?). I guess it just comes down to how complicated the implementation is. Because if TOC is auto-generated, then it doesn't need a LuaCATs grammar
  - My thinking basically is that manual TOC is low value, so the prioritization depends on difficulty. But tbf it's not a show stopper

- [ ] We need a solution for rendering rancher's keymaps and custom_cmds without having to directly extract the table data
  - [ ] A compromise could be to perform some kind of bespoke data extraction first, but that extraction has to be into something that the docgen can handle through a generalized process

- [ ] Where the docgen looks for "related" comments to a param/field needs to be consistent.
  - Lua_Ls needs documentation for function params/returns to be to the side and below, so we have to follow that I guess

- [ ] Make sure bullet rendering includes * and -. Maybe +
  - I think this is handled by the list dot and list minus tags, so just add list plus I think
  - You should be able to use Nvim's inspector to see the node names/ranges

- [ ] Look at the referenced docgens. Do they have ideas that are useful/valuable?

- [ ] This needs to have tests
  - [ ] The original _spec files will hopefully be helpful
  - [ ] Add a no_output option for validation/debugging

- [ ] Neovim is under an Apache license, which has attribution requirements attached to it. Must be in the README for this separate release

#### MID:

- [ ] Is it possible to re-write how the state machine works so it doesn't rely on niling values both to say "this isn't here" but also to break references that are passed to other tables. All of this causes a lot of re-allocation.

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

- [ ] I believe, for Markdown parsing, you get Nvim's built-in parser since Nvim is just opened as a Lua runner without awareness of other installed parsers. It should be possible to point the docgen to a parser of choice
  - Low priority because, IMO, this is not actually useful. And actually even creates problems in the context of a public repository

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
* https://github.com/folke/lazy.nvim/blob/main/lua/lazy/docs.lua
* https://github.com/stevearc/nvim_doc_tools
* https://github.com/lewis6991/async.nvim/blob/main/docgen.lua
* https://github.com/tjdevries/tree-sitter-lua - Maybe outdated, but useful
