## TODO:

This whole thing needs to be consolidated into nvim-tools

## REQS:

#### HARD:

- [ ] Don't use busted
  - The entire busted install is heavy
  - I have yet to see a method for using Nvim as a runner that I feel comfortable with
  - Multiple plugins use mini.test and Nvim core moved to a custom runner. Busted feels justifiably off-trend
- [ ] No appropriating the core's test harness
  - Complex code that is not inherently suited to plugins
  - Exception: Might be useful individual pieces
- [ ] Use mini.test
  - Used in a bunch of Folke plugins + fzf-lua
    * Battle tested under actual load
    * Useful wrapper scripts to make using it more ergonomic
  - Do not monkey patch or fork
    * Exception: If something mission critical is missing. Really should not be the case
- [ ] Must work in CI
- [ ] Must have a method to test `/plugin` files
  - Could be starting the test with a min init or a way to scan them in manually
- [ ] Need to be able to type `make test` and have it just work
  - I'm fine with not automatically git cloning the mini.test dependency, but then it needs to error and say how to resolve
- [ ] Needs to be modular
  - I'm not sure if I want to make a template repo for this, but I should be able to copy the gitignore, test helpers, and so on and they should just work
- [ ] Any make sub-files should be in `/scripts`
- [ ] The actual tests need to be in `/tests`
- [ ] It must be possible to specify specific files
- [ ] Needs to be possible to perform a clean start of Neovim, including no after files
- [ ] Something lazy.minit does that I don't like is it makes an external call to the lazy.nvim repo to pull its minit file. The make file should only be making external calls to purpose-built external repos, be they mini.deps or some kind of template repo
  - [ ] This would also include the docgen script

#### FLEX:

- [ ] It should be possible to output the results to a file rather than having to scroll through the cmdline
- [ ] Unsure where the test helpers should go
  - fzf-lua uses `/lua/plugin_name/test`. This is not unreasonable, as it prevents namespacing issues
  - I would prefer if it were a top-level folder beside `plugin_name`
    * If you just call it "test" or something, can cause namespacing issues
    * Giving it a plugin-focused name begs the question as to why it's not just in `plugin_name`
- [ ] There should be an ergonomic method to use something like `before_each` and `after_each`
- [ ] It should be possible to restart Neovim at different points in the test without having to create another runner
- [ ] It should be as clear as possible which operations pertain to the test and which prefer to the Neovim child process

#### SOFT:

- [ ] I would prefer if the testing syntax/construction were as imperative as possible
- [ ] I like the describe/it syntax but it's not strictly necessary or the best way to do it

## DEPS:

- [ ] How are make files written?
  - This does not require a deep dive, but some understanding of the overall structure/context of the files beyond just copy/paste
  - [ ] I'm guessing make is a program?
  - [ ] How does Nvim support make files?
  - [ ] What can make files do? Seems like a lot
  - [ ] Do they use a custom scripting language? What can it do?
  - [ ] Is the infrastructure around make files something that frequently changes?

## RESEARCH:

- [ ] fzf-lua
  - [ ] Tests
  - [ ] Utils
  - [ ] Make structure
- [ ] mini.nvim tests - https://github.com/nvim-mini/mini.nvim/tree/main/tests
  - [ ] Tests
  - [ ] The helper utils are spread throughout the various test files
  - [ ] There are also "-dir" files that have what look like context setup for the tests
  - [ ] Seems like a prime location for unique/deep hacks/techniques since Echasnovski made mini.test
- [ ] Lazy minit: https://github.com/folke/lazy.nvim/blob/main/lua/lazy/minit.lua
- [ ] Snacks and flash tests
  - [ ] See if they have helper utils

- [ ] testing framework
  - Conversation in here about Nvim as Lua runner: https://github.com/neovim/neovim/pull/39116
  - New core testing framework: https://github.com/neovim/neovim/commit/55f9c2136e52d8719495b6021ce7e8d64c5141fe
    * https://github.com/neovim/neovim/pull/38486
  - The best outcome would be to publicly expose the core testing framework. If I were to do it:
    * As a PoC, I would need to create a plugin-based extraction of it
      + This could be helpful simply because, in doing this, I might come up with something simpler than working with the core testutils
      + Regardless of that, the goal would be to understand, in more detail, what the test framework does and how it needs to be accessed to be useful
    * Based on my findings with the extraction, I would need to create an exposed dev build locally to make sure I actually knew how to do it
    * Make an issue
    * Make a draft PR
  - This is after docgen, because making a public version of the test utils is an awareness item for the core devs. Not the case with docgen
  - lewis's test plugin still feels like a source of relevant info
  - needs to be plug and play. Can't be doing a bunch of config to make it work
  - needs to work in CI
  - Should, if at all possible, auto-create new nvim instances between tests so that doesn't need to be managed

- [ ] make
  * [ ] test
    + [ ] Prompt if mini.test is missing
  * [ ] fmt
    + [ ] Run stylua
  * [ ] doc
    + [ ] Run docgen
    + [ ] Prompt if missing
  - [ ] lint:
    * This should basically be minimum viable product level If issues come up they can be addressed
    * An interesting question though is per-project linting rules.
    * I think core just dumped their linter from CI. Unsure if there's another useful one out there
    * [ ] WARN:
      + [ ] Diagnostic disable messages
    * [ ] FAIL:
      + [ ] Lua_Ls diagnostics
      + [ ] Formatting
        + [ ] Multiple newline only lines
        + [ ] Trailing whitespace

- [ ] https://github.com/lewis6991/gitsigns.nvim
  - Insanely well put together repo
  - Worth looking at in terms of like, what does a MakeFile give you that's valuable. How do you structure testing, and so on.
