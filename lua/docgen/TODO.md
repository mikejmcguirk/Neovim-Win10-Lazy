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
  * https://github.com/lewis6991/async.nvim/blob/main/docgen.lua
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

## Overall

#### TODO:

- [ ] Bring in mini.doc as a starting point, since it is the simplest, generalizable solution
- [ ] Look at Folke's generators. Is there anything form them I absolutely need.

#### MID:

- [ ] Not sure if it's for here, but whatever docgen solution I come up with, then automate it

#### LOW:

- [ ] Reading the files should be done async.

#### FUTURE:

- This is a task that wants to be written in a compiled language, since it involves so much text crunching
  * You could start getting really fancy with how the bytes are being read, rather than relying on higher level abstractions.
