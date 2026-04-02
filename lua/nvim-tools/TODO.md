## Overall

- [ ] Make sure everything has vim.validate in the params. It is easier for the user to remove than add them
  - Exceptions:
    - Validation functions (since they are, themselves, validators)

#### FUTURE:

- [ ] When https://github.com/neovim/neovim/issues/38420 releases, update everything to use it. Targets:
  * [ ] Option changes using misc.append_if_missing

## Docgen

- Relevant here for the config module
- We might also want to include a custom docgen tool here
- Requirements:
  * Must auto-format line lengths
  * Must be a combined solution for README and vimdoc
    + There simply should not be any documentation I have to write twice.
  * Obvious, but skip locals
  * Must pull up function comment docs
  * Needs to have some method of specifying and/or ordering files
  * There needs to be some method of extracting tables, like how folke does for his options configs. So that way you can just write the table in Lua and then get the result.
  * Heading generation needs to be as automated and simple as possible. This is something vimcats is good and bad on.
  * Need to be able to early-exit from modules like vimcats does.
  * Need to be able to do stuff like the brief tags to add custom comments
- Degrees of freedom questions
  * Should it parse purely semantically, or should it actually be able to look at the Lua code (say, pulling and iterating through tables) to get info?
    + My lean is semantic only. IMO a useful doc tool should let you stage docs in an order, and maybe with some flags (in the docgen and external) and then just work. Extraction-based docgen probably requires too much fiddling around.
      + Semi-counterpoint: Folke's extract tool is based on semantic extraction, which I think could be more useful. Because you can then take the high-level tools and compose them. I really think, from experience, that individual file reads put you too much in the weeds.
  * How do we document options effectively? You can make and extract a default table, sure. But what about g:vars? Are you saying that you need to build them off a table?
    + This is *probably* something where I can like look at the tools out there and maybe come up with something, but most likely it just needs to be composable, generalizable solutions.
  * The question of "do you put the markdown intro into Nvim" actually matters, because if the answer's yes, then the answer is basically panvimdoc. If the answer's no, then file stitching becomes more relevant.
  * For functions, needs to correctly handle self: syntax

- Possibilities:
  * https://github.com/folke/snacks.nvim/blob/main/lua/snacks/meta/docs.lua
  * panvimdoc
    + Though this doesn't solve the problem of how the function documentation gets into the md file
    + On the other hand, it does solve the problem of - Nvim's docs should just be in markdown
  * https://github.com/lewis6991/gitsigns.nvim/blob/main/gen_help.lua
  * https://github.com/tjdevries/tree-sitter-lua - Maybe outdated, but useful
  * https://github.com/stevearc/nvim_doc_tools
  * https://github.com/folke/lazy.nvim/blob/main/lua/lazy/docs.lua - I'm not exactly sure how this works, but there are interesting ideas in here on how to extract data from the Lua code itself
  * A semi-goofy but not entirely unjustifiable idea would be to just do the docs in Markdown.
    + One issue - The image links are a bit lame if you don't have an image viewer. Though there are sketches of how to do this in Nvim
    + Helptags actually do work, but they are not formatted in any special way since to Markdown they are not meaningful syntax
      + Both in terms of the tag generation itself and the jumping
  * It is also relevant to consider the idea of porting Neovim's actual docgen.
    + Advantages:
      + Handles whatever formatting is thrown at it
      + Useful syntax like inlinedoc/nodoc
      + Brief is just done with one tag at the start of a comment block
    + Disadvantages:
      + A lot of code
      + Would need to double-check that there isn't a licensing thing with the Luacats syntax. Almost certainly not but worth being sure.
- Preliminary Conclusions:
  * IMO the gitsigns docgen is the strongest candidate. The formatting looks excellent.
    + Not sure if it contains a README solution
  * But if you go the "but really, it should all be the same docs route, including the README intro presentation", then the answer might be to look at how to extract the docs into *Markdown* so that panvimdoc can convert them. This would basically be what snacks does. This would also position for a future maybe possibly hopefully move away from vimdoc
  * Whatever the solution, I should try to make this something that is genuinely generalizeable. Looking above, you have panvimdoc and then a couple different bespoke tools. This seems/feels bad man.
  * Something to consider, and it's almost worth making a Lua meta file for this, is to think about what the interfaces should be.
    + It would need to be something where you could use it at any skill level/ambition level. If you just want to plug a couple filenames in and spit out docs, that should work. If you want to structure your own like, per file actions, you should be able to do that.
      + It does feel like that makes sense as a high-level idea. You have like a master table of the files (in order), with actions (you can set actions to nil to just do a generalized syntax extraction), and then an output file. Though if you want it all to go to the same file, that's a bit lame. So maybe you just run multiple docgens for multiple files, which I think is fine. Anyone can make a runner script to batch them together
        + And then I think you should just treat it as a hard constraint that each file's state is wholly self-contained.
          + Maybe have an option to auto-add headings to each file. But you should probably just type out the @mod text.
  * A conceptual tension here is, you have specific extracts vs. treating the files almost like a syntax tree.
  * Would want to start from the basics and build them up
  * IMO a lot more research needs to be done on how the docgen solutions so far work.
- Concrete steps:
  * Would want to test whatever I'm working on using a bunch of different plugins. Will provide validation that it works both in the technical sense (no failures on different types of documentation) and aesthetic sense (doesn't look terrible)

#### MID:

- [ ] Not sure if it's for here, but whatever docgen solution I come up with, then automate it

#### LOW:

- [ ] Reading the files should be done async.

#### FUTURE:

- This is a task that wants to be written in a compiled language, since it involves so much text crunching
  * You could start getting really fancy with how the bytes are being read, rather than relying on higher level abstractions.

## Config

#### TODO:

- [ ] Type annotate everything properly since Lua_Ls doesn't auto-detect them.
  - [ ] Including fields in both metatables
  - [ ] Make them class exact? Unsure if I want to double-define the self methods though
- [ ] Use this module as the template example for the docgen
  - [ ] Make sure metatable class documentation is correct

#### DOCUMENT:

- [ ] Invalid buf_ids in buf_config hard error
- [ ] The main config does not allow setting nil and does not allow for niling itself out. The buf configs do allow this
- [ ] Explicitly setting a buf config to nil clears it

#### MID:

- [ ] When :file or :saveas is used to change the name of a buffer, the new buffer inherits the original buf_id, and the old file/filename are given a new buffer number. It could be interesting to use some sort of logic to make sure that the old buffer id is given a copy of the new file/old buffer id's buf_config.
  - Counterpoint: Since I don't want to have config for config, adding the above behavior means the user is locked into it if they don't want to be, whereas, if this is not default behavior, the user can opt into it themselves if they want to.
- [ ] It would be good if buf_configs were pro-actively managed to remove nil configs.
  - The problem is I don't know where to do it except on read, which slows down something that is presumably performance dependent
  - Maybe use vim.schedule?

#### LOW:

- [ ] Is it possible to have a Root_Proxy that solely contains the __call method?
  - Problems: Both the __call method itself as well as __newindex rely on being able to use __call recursively
- [ ] Is it possible to put proxies on the non-config sub-tables in a way that (a) isn't contrived and (b) doesn't hurt PERF.
- [ ] In Buf config, when doing an __index, it is theoretically possible to check if the config has no values and nil it out if not. But since reads are performed during user operations, we do not want to take a detour to free memory (slow, and potentially triggers garbage collection).
- [ ] It might be faster, for deleting autocmds, to check a cache for the group id rather than re-constructing the name string. I'm not sure this matters enough to justify maintaining the state.
  - [ ] Counterpoint: This also might matter for __newindex, meaning we're saving more perf
    - [ ] Counter-counterpoint: I think it's a mistake to make too many assumptions about state and how state is built

#### FUTURE:

- When g/b variables are able to store metatables, in order to handle pre-init user configs, the config module should first create the default config, then use its __call metamethod on the pre-existing g/b variables to bring in the meta-data.

#### MAYBE:

###### Buf Config

- Allow non-integer datatypes for the key in __newindex. At least for now, I would prefer as many guardrails as possible around this metatable, since it deals with recursive behavior.
- Provide a return value in __newindex so you can get a quick indicator of what happened.
  * The underlying table state change could be nil > nil, value > nil, nil > value, value > new_value. Depending on the input, the different nil state changes could be intended or un-intended.
    + Given that, would rather hold on this idea until a concrete use case.
- In theory, you could have a function like create_from_default() that creates a buf_config from the default. There might be other ideas about initialize buf configs. But as of right now, I think the current tools are sufficiently composable.

#### NON:

- If the filename is changed using `:file` or `:saveas`, do not use an autocmd to copy the config to the new buf-id/old file. Because I don't want to have config for config, this locks the user into a behavior they might not want (it is theoretically possible for the user to delete the autocmd group, but this is contrived and touchy). As is currently the case, the user can add this behavior if they want.
- Similarly, be cautious about adding new automatic config delete conditions. If the user, say, wants to add BufDelete, they can make their own autocmd.
- Don't auto-create new buf_configs if you __index into a nil buf_config
  * Actual Lua tables don't behave this way, so it's an anti-pattern
  * This behavior would then require a bespoke accessor function to check if a config exists and is not empty before actually reading the value(s) from it
  * Correctly handling "gc" for empty buf configs is tricky. Don't want to introduce conditions under which tables can be needlessly created

## Buf

#### TODO:

- [ ] Add an algorithmic save function
  - [ ] TODO scoped under the presumption that not all corner cases will be covered. Those can be prioritized down
  - [x] Should appropriately handle errors while saving
  - [ ] If there's no file on disk, should that file be created? Or is that an abort?
    - I think the way I have it right now is probably best, in that it should not insist upon itself if the file's not on disk. If/when bcd is added, I think an opt to use that to save to disk would make sense. Add a FUTURE note somewhere
- Canned script for creating a temp-buffer for window and tab opening purposes. See the code I have in vim-dadbod

#### MID:

buf_open improvements:
- [ ] open_buf
  - [ ] do_set_buf options
    - [ ] It should be possible to provide your own post-load, pre filetype options
      - Idea: A callback is provided with buf as a param that's run in the proper window context. You can write your own custom options to set in there. Maybe provide a boolean for if this overwrites or appends to the default behavior
      - More Complex Idea: Do these option sets from a table. Allow the user to specify their own table along with merge behavior or total removal of the default
        * Problem: How do you handle setting opts based on programmatic conditions? You could use some kind of table function arg, but this is starting to sound goofy.
      - [ ] Make sure that ftdetect is handled for buftypes that are non-specific
    - Like the ones that already exist, new options for this function should be layerable and composable, rather than creating new path dependencies

#### LOW:

- [ ] Smarter `open_buf` filetype detection:
  - With help and qf buftypes, the current trade-off is to sacrifice potential nuance in behavior and performance for reliability, both in avoiding filetypedetect and making sure ftlugins are always able to overwrite post-load settings
  - It may be possible, based on the previous buf/win settings, to let one of both of the FileType and filetypedetect events fire
  - This is tough because
    * Vim tracks if ftdetect occurred based on, seemingly, a few different backend settings. I would prefer not to get them and their meanings mixed up
    * `do_ecmd` and `open_buffer` do not have the same behavior. I would need to cross-reference both of them to get the result I'm looking for
    * At least for now, I have yet to see a use case that strengthens the cost/benefit analysis

#### MAYBE:

open_buf
- An opt could be provided for setting the pcmark, but I don't know what the use case is
