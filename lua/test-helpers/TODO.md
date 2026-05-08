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
