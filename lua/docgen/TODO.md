## General

#### TODO:

render lower level md heades as the green squiggly
if we want to do equals, dash, and green, then that gives you 1/2, 3/4, 5/6. feels simple, even though tilde borders aren't included

- [ ] Still interface problems:
  - [ ] If you make gen_vimdoc, gen_readme, and gen_plugin separate functions, you have to re-run the file reads for all of them. Very slow and bad.
  - [ ] It seems reasonable that each rendering would take in a list of file paths, types, and texts.
  - [ ] It further seems reasonable that, for read, we would scan all of those lists to build a file list, since we would be building a hash table anyway. And then each one could use the same hash table.

- [ ] Parser_obj warnings need line/file info to be useful
  - [ ] Add the filename to the parser obj once so the reference doesn't have to be moved every line
  - [ ] Pull the i out of ipairs for the line number
  - [ ] Rather than pass line + idx + fname to every sub-function, have them return ok, err and the transform dispatcher can handle

- [ ] Test if the extra trailing newline in ts_parsing is needed after this: https://github.com/neovim/neovim/commit/7ed5609439ba83d75e972beb859245d998df09ea - Does this affect if a trailing newline needs to be added at the end of the str when parsing LuaCATs to MD?

- [ ] The remaining TODO comments in the rest of the docgen are placed reasonably. Just work through them without moving here.

- [ ] Documentation plan:
  - General plan: use a combination of generators to create the underlying LuaCATs data and plugin files, then use the vimdoc generator to stitch together the docs
  - Unsolved problems:
    * How to get default config
      + Just extract it?
        + Do what folke does and find the line it's on by string
    * Linting
      + Have a script that makes sure changes in the gen files vs. the destination files are consistent
    - Folder structure
      - `/` (README, LICENSE, MakeFile)
        * `/lua`
          + `/docgen` (The actual docgen files)
        * `/scripts` (runner, test scripts)
        * `/tests`
  - Problems with Plans:
    * MD Generation;
      + After playing with this a bit, it is a more tractable problem than I figured, and the solution will be vendored
      + Because the updated parsing still creates vimdoc, we want the vimdoc generator to be able to take Lua and Markdown files as inputs. Technical details TBD
      + The same markdown parsing needs to be used for LuaCATs and raw MD files. Trying to sneak in different tweaks for LuaCATs IMO is a bad idea
        + Fallback position: Pass some kind of table or function variable to handle differences
      + This also means that the gen_vimdoc script can function as the stitcher, at least for vimdoc
        - README assembly probably still needs to be a separate program, but that's just reading and concatenating files
      + Importantly, this means the data files can generate whatever pieces we want.
      + One pressure point this does add is - We need to be more mindful of catching duplicate helptags. And bringing in the MD files directly means more questions in terms of how the filename generation is scoped. The overall algorithm is the same, but then what we're basically saying is that the toc will have the help prefix only as its tag. Like with the data LuaCATs files (where either filename has to be "keymaps" in the root dir or init.lua in the keymaps dir), we have to think about what data files we are generating.
        + It would probably be useful to say that markdown files should join to the filepath with a `-` rather than a `.` since they aren't Lua modules. Then you could have "keymaps.md" and so on the main Lua dir and then get "help-prefix-keymaps" as the top level tag.
      + The "data" files should generate markdown that looks nice first and foremost. The vimdoc parser should be able to handle them.
    * Keymaps/cmds/hl_groups/autocmds/opts
      + Put them in a gen file that's table based. Use that file as the basis for the vimdoc/md/plugin file
      + Have "extended doc" field for stuff that doesn't go well into the Nvim desc field
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

- [ ] Where the docgen looks for "related" comments to a param/field needs to be consistent.
  - Lua_Ls needs documentation for function params/returns to be to the side and below, so we have to follow that I guess

- [ ] For writing briefs, how can we make sections with custom sub-headers and indented text?
  - Motivation: Making the README more aesthetically pleasing.
  - Syntax might be: `---@note sub_header name\nThe indented text`
    - Problem with the above, how do you put in line breaks?
    - Possible solution: When a note tag appears, it collects doc lines like params and returns do. When the next tag hits, resolve the note. In a function or class, this would be collecting the doc lines then proceeding to the next thing. In a brief, you would be able to do @brief again in the same brief to go back to normal formatting.

- [ ] Look at the referenced docgens. Do they have ideas that are useful/valuable?

- [ ] Function contracts need updated

- [ ] For convenience/demonstrative/documentation purposes, include a docgen_runner file for generating the README

- [ ] This needs to have tests
  - [ ] The original _spec files will hopefully be helpful
  - [ ] Add a no_output option for validation/debugging

- [ ] Do a final audit that everything consolidates its output to a string when possible.
  - [ ] Does this include the treesitter parsing?

- [ ] In the parser object, do a last check that each set does the proper checking
  - [ ] If it can be taking invalid LuaCATs, assert
  - [ ] Values should be nil'd where possible

- [ ] Neovim is under an Apache license, which has attribution and derivative license requirements attached to it

- [ ] Internalize any nvim-tools functions.

#### DOC:

- [ ] Markdown parsing assumes two space indenting (Treesitter constraint, not my code). So if you start a list indented by two, the parser will recognize this and give you an indented list. But if you start it indented by four, it will see it as an indented code block.

- [ ] The documentation should be written as LuaCATs annotations and self-generated. This both demonstrates that yes, it works, and also allows for the doc itself to show how it works.

- [ ] Starting a new annotation kind without an intervening blank line is an error.

- [ ] Underline functions/params/fields are not rendered.
- [ ] (default: `foo`) will auto-format with params and fields
  - [ ] Does not work with returns
- [ ] Because class/field/overload side annotations are not read by Lua_Ls, they are only used here if no doc lines above are present

- [ ] Nested inlinedoc is unsupported behavior.

- [ ] Access flags:
  - [ ] Work on whole functions, class fields, or aliases
  - [ ] VERIFY: Doing private instead of exact for class doesn't seem to do anything

- [ ] `@mod` annotations do not automatically generate tags.
- [ ] `@divider` does nothing outside of a mod block

#### TEST:

- [ ] The Luacats grammar should never be able to return leading whitespace for desc (or really anything)

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

- [ ] Tie deprecated functions with their replacements
  - My best idea at the moment: Add a `@replaces` tag. During the holistic step, each replacing function looks for a `@deprecated` tag with a matching description. If it's found, the "Use X instead" tag is injected. This is a bit of a dialect, but it doesn't contradict Lua_Ls and it works
    * Would have to think about how the iteration is done + how the tags are added since deprecated/replaces can be a many-to-many relationship
    * This logic could also be applied to target the `see` tags of other items.

* [ ] While the auto-generated tags need to be produced for holistic identification, there should be an option to not use them if a `@tag` option is present, or even to not use them at all.
  * [ ] Possibly also have `@notag` and `@noautotag` annotations for more control

- [ ] Put log lines into a queue and only write every X lines
  - [ ] DEP: Logging does not currently happen enough for this to be a perf bottleneck, nor are we writing frequently enough to worry about degrading SSDs

- [ ] The handling for access tags should be smarter.
  - [ ] Example: Private is seen on a non-kind block. The kind turns out to be brief or class. Access should be set to nil and a warning emitted.

- [ ] `@mod` annotations should support
  - [ ] `@deprecated`
    - [ ] To denote the whole block as deprecated
  - [ ] `@see` To do global corollaries

- [ ] https://github.com/neovim/neovim/commit/d7ef55e8817627af0f25dc2bb9ed9927d0049d6a - Additional generics handling
  - DEP: These are emmylua_ls only. I have not migrated there yet.

- [ ] Support recursive inlinedoc like the core's docgen
  - Currently mostly works, but details are not sorted out:
    * Because inlinedoc injections are not processed in any particular order, this should mean that it's possible for the top level class/function to pull in a class for inlinedoc before that class pulls in its inlinedoc field
    * This means that the inlinedoc injection itself needs to be recursive, which checks in each injector to check if the desc is already a table so the process isn't repeated.
    * There also needs to be a check against infinite recursion
      + I think, for each strand of the recursion, you'd keep a map of the names, so if you had a hit inside the map, you would error. I think this works if you assume that, for each level of injection, no other args will have an injection, but I don't know if the check works laterally.
      + If you wanted to keep it to only one map, I think you would need to add/remove the key outside the scope of the injection. So before you moved into the function to inject class foo, you would need to add class foo, then remove the key before checking the next arg.

- [ ] Allow classes without fields to render
  - [ ] DEP: I don't know what the concrete use case for this is, so I don't know what I'd expect to see.

- [ ] Figure out a way to make the docgen take in raw strings
  - Motivation: Writing temp files for docgen is a waste of disk IO
  - Problems:
    * I don't know what a good interface in would be
    * I don't know how to figure out the helptags in a way that isn't contrived

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

#### NON:

- Removing the dependency on Neovim as the Lua runner. This would require fundamentally re-engineering how things like async file read work and re-creating fnamemodify.

- This docgen inherits Neovim's removal of underline named functions. This is a useful convention, and no option will be provided to disable it.

- `stylua: ignore` works with two dash comments, so no need to manually filter it here.

## REFERENCES

* https://github.com/neovim/tree-sitter-vimdoc
  + https://neovim.io/doc/user/helphelp/#help-writing
  + https://github.com/nanotee/vimdoc-notes
* https://github.com/folke/snacks.nvim/blob/main/lua/snacks/meta/docs.lua
* panvimdoc
  + Though this doesn't solve the problem of how the function documentation gets into the md file
  + On the other hand, it does solve the problem of - Nvim's docs should just be in markdown
* https://github.com/lewis6991/gitsigns.nvim/blob/main/gen_help.lua
* https://github.com/folke/lazy.nvim/blob/main/lua/lazy/docs.lua
* https://github.com/stevearc/nvim_doc_tools
* https://github.com/lewis6991/async.nvim/blob/main/docgen.lua
* https://github.com/tjdevries/tree-sitter-lua - Maybe outdated, but useful

## Keymap

#### META:

#### TODO:

+ [ ] The biggest acid test of this module is rancher
