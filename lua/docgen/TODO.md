## General

#### TODO:

- [ ] Tag combination and injection
  - Possible tags:
    - `{help-prefix}-{modvar}.{namevar}()` module function
      * The init module case should already have the tags rendered out properly
    - `{help-prefix}-{classname}` class definition
    - `{help-prefix}-{classname}[:.]{namevar}()` class function
  - [ ] Data issues:
    - [ ] Since we need to wait for the class name to define a class function, we need to hold onto the member sep
  - Circumstances to build tags + info
    - Initial function creation
      - This is good to go if it's a module function
      - If not, you have to construct an initial name from `classvar[:.]namevar` to uniquely identify during the holistic step. Then it needs to be replaced during the holistic step
    - {include tag injections here}
  - Ideas
    - Don't greedily make fmt name?
      * Doesn't work because of function holistic identification

- [ ] Tag space replacement with underscores?

- [ ] I guess we just switch metatables for render_obj. The parser obj is too big and its concerns too co-mingled. If I step away from it for a couple days I can't remember what anything in it does.
  - [ ] inline doc will go in the rendering stage. You can output "render_obj" from the holistic step for clarity.

- [ ] Add a list of tags to the parser objects based on collected @tag annotations and generated tags. Store in generated order.
  - [ ] Do you have an option for only generate tag if no @tag is present? Do you control this with annotations? Something like `@notag` or `@noautotag?`

- [ ] Add code to ignore stylua tags
  - I think the core's docgen does this. If not, I have to imagine that some other one out there does. Or I can just look it up

- [ ] Executive decision: Parsing rules need to match what Lua_Ls does
  - [ ] DOC: No after desc for class desc or operators
  - [ ] DOC: Fields are probably the same
  - [ ] Same for aliases
  - [ ] Make a maybe/future note that if emmylua_ls supports this a change can be made

- [ ] buzz issues:
  - [ ] Important - newline fixing is not correct. Cannot get double newline break
  - [ ] Less important - nested bullets not working
    - [ ] possible solution - handle indenting in md parsing but keep it purely internal. then you can do structured incrementation on bullets

- [ ] I don't know if it's necessary or a good idea to build this out fully now, but we want to make sure some of the skeleton is out there to handle warnings. Because we want to be able to write them to a log if the user wants
  - Related to this, I think I threw out all the logging stuff a bit prematurely. The overriding problem is that basically everything in the docgen is a hot path, but like, are there transition points where it makes sense and doesn't create too many IO hits?

- [ ] @nodoc auditing:
  - [ ] Should override everything else
  - [ ] Should only work at the kind level
  - [ ] Unlike access, which Lua_Ls makes effectively invisible, I don't think you can just toss nodoc items

- [ ] Access
  - [ ] DOCUMENT: only works on class stuff
  - [ ] verify it only works for classes
    - [ ] Should not be able to put access on functions and have it do anything
    - [ ] So like, I don't think you can pre-emptively reject access tags because they can come before class declarations, but it can be rejected if kind is affirmatively something other than class, and the checks on access check also check class status

- [ ] @deprecated needs to be treated here like @nodoc (avoid needing redundant annotations)

- [ ] Need a better/more coherent way of managing how classes are referenced.
  - We need to hold a table of class references by name for inlinedoc purposes
  - I would think/hope that you can just put the classes in a master object list and hold the name ref for inlinedoc only and be done with it

- [ ] Handle core updates:
  - [ ] https://github.com/neovim/neovim/commit/7ed5609439ba83d75e972beb859245d998df09ea - Does this affect if a trailing newline needs to be added at the end of the str when parsing LuaCATs to MD?
  - [ ] https://github.com/neovim/neovim/commit/d7ef55e8817627af0f25dc2bb9ed9927d0049d6a - Additional generics handling
    - Might not be relevant for now though since this is for emmylua. If not, throw into FUTURE because I get the impression the long term push is to migrate there

- [ ] Delete docgen_00.lua at some point. Want to hold onto it though in case it has old code I want to use, like for warning emission

- [ ] The remaining TODO comments in the rest of the docgen are placed reasonably. Just work through them without moving here.

- [ ] The parser_obj's functions should mostly be private

- [ ] Seriously considering not using the mod tag. The rough ideas I have in my head mean that you would just make different files for everything.

- [ ] Perhaps, instead of `@mod`, do `@section` and change the verbiage in rendering to mod. This would make both things make more sense.

- [ ] Plan rough idea: Mostly do this based on file generation. So you'd have big files for "keymaps", "cmds", and so on, and you'd use them to export files with LuaCats and stitch them into the `/plugin` file. This kind of makes sense anyway since `/plugin` should not contain serious business logic. Based on the filename > tag resolution, you would so something like create `lua/keymaps/init.lua` to make the tag show up as `*plugin-keymaps`
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

- [ ] The future items below require building out logic for when module headings are created. The vimdoc treesitter page has a link to the vimdoc spec. Read and familiarize.
  - Initial findings:
    * The github article on the treesitter page goes over the regex syntax for each element. We can use this to validate certain elements, like helptags

- [ ] If the parser object is set to a module type, it should be able to accept contiguous @tag annotations. My guess is that it's probably right to push tags to be on the top of doc blocks. So when a module is found, it should pull in any tags as well. If a tag is found with no kind, it should be stored for the committed object. It should probably be allowed to put in arbitrary tags that are not used, so that way if you need to temporarily add @nodoc to something the docgen doesn't spaz out. Maybe emit a warning.
  - [ ] Probably also keep in mind data sanity here as well. If you have something that's @inlinedoc, tags can be thrown away. One caveat though - Does this trigger more gc?

- [ ] I want to be able to, after parsing, be able to traverse the created objects and create/render the TOC before rendering. The data should be available to do this
  - This also implies that a lot of info like helptags should be ready to go before rendering, which might impact a lot of the stuff below

- [ ] For toc:
  - As you make sections, collect the header tags in order, then do a list of:
    * Section_Name.......|section-name|
  - Numbering or fancy bullet formatting IMO are optional.
  - Doesn't have to have dots separating the TODO text. Might be a bit noisy
  - It would be helpful if you could just re-use the header formatting code

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
    - [ ] The docgen should be able to check @tags and see if they begin with the help_prefix. If not, it can be prepended
    - [ ] It should also be able to handle whether or not the user surrounds it with * characters
      - [ ] Though see what vimcats does. Maybe worth developing a bit of a standard around that.
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

- [ ] For writing briefs, how can we make sections with custom sub-headers and indented text?
  - Motivation: Making the README more aesthetically pleasing.
  - Syntax might be: `---@note sub_header name\nThe indented text`
    - Problem with the above, how do you put in line breaks?
    - Possible solution: When a note tag appears, it collects doc lines like params and returns do. When the next tag hits, resolve the note. In a function or class, this would be collecting the doc lines then proceeding to the next thing. In a brief, you would be able to do @brief again in the same brief to go back to normal formatting.

- [ ] My assumption right now is that, by default, the help_prefix can be calculated based on the file inputs. It seems reasonable that the user could provide a custom one. Just unsure how that's handled because I'm not totally sure how the docgen should take input yet. CLI only? CLI and script? Script only?

- [ ] Look at the referenced docgens. Do they have ideas that are useful/valuable?

- [ ] For convenience/demonstrative/documentation purposes, include a docgen_runner file for generating the README

- [ ] Folder structure
  - `/` (README, LICENSE, MakeFile)
    * `/lua`
      + `/docgen` (The actual docgen files)
    * `/scripts` (runner, test scripts)
    * `/tests`

- [ ] This needs to have tests
  - [ ] The original _spec files will hopefully be helpful
  - [ ] Add a no_output option for validation/debugging

- [ ] Do a final audit that everything consolidates its output to a string when possible.
  - [ ] Does this include the treesitter parsing?

- [ ] In the parser object, do a last check that each set does the proper checking
  - [ ] If it can be taking invalid LuaCATs, assert
  - [ ] Values should be nil'd where possible

- [ ] Neovim is under an Apache license, which has attribution and derivative license requirements attached to it

#### DOC:

- [ ] The documentation should be written as LuaCATs annotations and self-generated. This both demonstrates that yes, it works, and also allows for the doc itself to show how it works.

- [ ] Starting a new annotation kind without an intervening blank line is an error.

- [ ] Underline functions/params/fields are not rendered.
- [ ] (default: `foo`) will auto-format with params and fields
  - [ ] Does not work with returns
- [ ] Because class/field/overload side annotations are not read by Lua_Ls, they are only used here if no doc lines above are present

#### MID:

- [ ] It should be possible to pass a custom function to convert the filenames into header tags.

- [ ] For `class (exact)`, exact comes in as an access specifier. Store the specifier and display it as an attribute.

- [ ] Add optional debug timers

- [ ] Add more patterns to recognize function and class declarations
  - [ ] DEP: This would depend on having concrete use cases for doing so. The core's docgen is written for their use cases, which don't match 1:1 with the plugin world.

- [ ] Update the type/name fixing to handle more nuance. A name having a question mark means something different then the data type having a question mark. `type|nil` means something different than `type?`
  - [ ] DEP: The name/type code needs to be properly distinguished and super/subsetted from what inline doc uses, as well as making sure individual cases like params vs fields are handled correctly.

- [ ] When doing line iteration, when you hit an annotation line, iterate ahead to the first non-annotation line to see if it's invalid (returns for example). If so, skip the doc block. If the line is valid, then only send the doc block range of lines to the parser object
  - [ ] This would mean that the `string.find` check on each line would be done externally, and add_line would assume that incoming line is a doc line. Because parsing failures get added as doc lines, this does not break the internal validity of the data.
  - [ ] This would mean that the caller would have to always manually call `finalize()`, but since the question of "what is a doc block" is being moved outside the parser object entirely, this doesn't muddy the abstraction boundary.
  - [ ] Would likely not go beyond just checking the non-doc line after. Otherwise, you start moving the question of "what is a valid doc block" outside of the parser object, which would mean either a blurry abstraction boundary or re-writing parsing to be fully procedural. If the latter were on the table, you'd be in the territory of just doing a compiled language rewrite.

- [ ] Using all-encompassing types for parser objects and doc items was the wrong decision, because you're forgoing the benefits of Lua_Ls's diagnostics and losing the information that the type annotations convey.
  - [ ] Use aliases where possible to avoid big type union chains.

- [ ] The field/param/return iterators create leaky abstractions because they expose the underlying table data directly. Based on the use cases, the iterators should return the de-composed fields.
  - [ ] This is a problem for returns because they contain an inner component. I guess that you'd return an iterator for the inner returns, but that starts to get more convoluted than just returning the raw values.

#### LOW:

- [ ] It might be faster to, at the start of a doc block, do a minimal iteration to the first non-annotation line to see if it invalidates the block.

- [ ] Support recursive inlinedoc like the core's docgen
  - [ ] DEP: I would not want to attempt this without first converting inline doc processing into a more data-based model, rather than ad-hoc text-injection.
  - [ ] Blocker: How do you prevent infinite recursion?

#### SPEC:

- [ ] The markdown parser should use byte positions to reason about how to perform output formatting, instead of just relying on node types
  - [ ] DEP: Difficult/complex, and therefore requires numerous use cases. So far:
    - [ ] Wanting to create bulleted lists with a line break before them
    - [ ] Wanting to indent bulleted lists without having to use some kind of sub-section
    - [ ] Allowing the user to think less about how formatting will be handled when writing docs

- [ ] Add performance profiling. This would allow optimizations to be targeted where they would actually produce an impact.
  - [ ] DEP: The logging needs to be setup such that anything can just plug into it. You can't be having to create new infrastructure for this.
  - [ ] The profiling would need to group specific tasks. So for something like function rendering, you would want to add hrtime for each function rendered, then get the total time + time per function.
  - [ ] The profiling cannot create new branching logic.
  - [ ] The best way to do it is probably to hold the profling info in a global so it doesn't get into the overall control flow. Or, if globals are inherently slow, then hold it at the module level and have a way to export it
    - [ ] DEP: How does lazy.nvim do it?

#### FUTURE:

* This is a program that wants to be written in a compiled language.
  + Motivation: More efficient heap usage and object oriented constructs
  + Problems: Harder to write/use

#### MAYBE:

* Support custom helptag prefix generation
  + Motivation: The current method introduces a stringent constraint on how projects can be structured. It also does not support str/lines inputs. This is not helpful if I want to generate stuff like keymap docs without creating an intermediary file.

- Support string or lines inputs
  * Blocker: Introduces a lot of different assumptions you have to resolve on input intake.

- Support more patterns for matching text to functions or classes. Depends on use case.

- Support the `@note` annotation
  * Motivation: It would not be that hard and it can be convenient
  * Problems: The annotation is not supported by Lua_Ls, and any reduction in complexity surface area is worthwhile. It also feels like a "catch-all" way of organizing things.

- The "doc_text" field and the specific @deprecate handling are a minimally disruptive, ad hoc solution to a specific problem. Storing table data for doc flags in a principled manner opens up an architectural can of worms that is best avoided. If use cases come up for adding text to the other doc flags, or another case is found where an enum Parser Object field needs to store accompanying text, this can be revisited.

- There are a lot of places, such as briefs, where help tag injection could be used, but spamming the behavior adds footguns and perf costs. This function should be added somewhere in response to specific use cases, after more tailored behavior has been ruled out. (For example, rather than applying this globally to brief text, it would be better if `@see` tags were supported in an ergonomic way.)

#### NON:

- Removing the dependency on Neovim as the Lua runner. This would require fundamentally re-engineering how things like async file read work and re-creating fnamemodify. If we're doing that, better to just re-write it in a compiled language.

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
