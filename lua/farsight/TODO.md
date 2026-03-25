## TODO:

#### Config

- [ ] Research
  - [ ] How other plugins handle config merging and verification
  - [ ] The vim.lsp.config metatable

- [ ] Main config table
  - [ ] Access with require("farsight").config
  - [ ] Access controlled with a metatable
    - [ ] Probably outline definition from table declaration so that it can be restored if needed
    - Outlining the definition should also make it easier to attach the metatable to buf_configs
  - [ ] config.timeout = 500 -- Validates input and overwrites current
    - [ ] Should hard error on failure
  - [ ] config = { timeout = 500 } -- Merges new table into current if fields are valid
    - [ ] Invalid values should hard error. Extra values should be skipped silently
  - [ ] config.tokens = extend_in_place(tokens, { "a", "b", "c" })
    - [ ] extends config.tokens
  - [ ] config.tokens = { "a", "b", "c" }
    - [ ] Overwrites config.tokens
    - [ ] The metatable needs to understand the difference between sending a table arg to the config table as a whole or to a key
  - [ ] config.tokens = nil -- Either a no-op or hard error
  - [ ] config = nil -- Either a no-op or hard error
  - [ ] local foo = config -- Provides a deepcopy of the current config
  - [ ] `checkhealth` should be able to verify that the config table has all expected values, that all values are valid, and that the metatable is present and correct
  - This method simplifies transitioning to g/b variables in the future when metatable support is added

- [ ] `get_default_config` returns a deepcopy of the current config
- [ ] `reset_config` Resets the config back to the defaults
- [ ] `restore_metatable` in case the old one is removed or corrupted

- [ ] buf_config tables
  - [ ] Research
    - [ ] How the vim.b accessor works
  - [ ] Accessed using require("farsight").buf_config[{buf}]
  - [ ] The top level buf_config map should be protected by a metatable
  - [ ] Each buf config does not need to have all the same options as config, or even exist
  - [ ] Each individual buf config should have the same metatable as config
    - [ ] Make exceptions as needed given that buf config fields are optional
      - [ ] In particular, unlike config, it should be possible to nil a buf config field
  - [ ] An autocmd should run when bufs are closed to clear buf_configs
    - [ ] This should be setup on require
  - [ ] For all functions that use config, buf_config should take precedence if it exists
  - [ ] DOCUMENT: An example of using a filetype autocmd to set a buf option
    - [ ] Either as the main buf_config example, or as an additional one, show an example of how to use an autocmd on the buf to get project information

- [ ] Options:
  - [ ] set_default_maps
  - [ ] Function specific options
    - [ ] csearch
    - [ ] static
    - [ ] live

#### API Requirements

- [ ] APIs
- [ ] All APIs should be run through this module
  - This way, you can always do something like `require("farsight").csearch()`
  - Allows documentation to be centralized
  - [ ] Each API that runs through this module should have a sub-table in config
    - [ ] This way, a calling function only needs to get a reference to the sub-table once
  - [ ] If neither buf_config nor config exist for the option, get default config
    - default config is only a fallback. It should never be possible to actually remove a setting from config
    - In particular, getting default config is slower since it requires a deepcopy of the whole table

- [ ] All Plug mappings should use the public APIs
  - This avoids complication around Plugs having different behavior due to separation of validation and resolution

#### Polish Step

  - [ ] Add `desc` values to Plug and default mappings
  - [ ] Verify that the `require("farsight")` call in /plugin.lua does not require other files

#### csearch

#### Live Search

#### Static Jump

## MID:

- [ ] Is fzf-lua's deep_clone function useful?
- [ ] In the documentation for buf_options, show an example of using an autocmd to get project information and set an appropriate buf option
  - [ ] Look at https://github.com/tpope/vim-projectionist
  - [ ] What is a concrete use case? Perhaps, in a web development project, if you are in the frontend part of a project, you might want csearch to highlight the various markup characters, whereas in the backend part of a project that might be too noisy

## FUTURE:

- If/when Neovim adds project scope/project config, see if that prompts a change in how config is handled.
