## General

#### DEPS:

- [ ] The nvim-tools config module needs to completed
- [ ] I need to decide if I'm using search here as the template for Nvim-tools, or building the search in Nvim-tools first
- [ ] Docgen
- [ ] Generic modules in nvim-tools need to be complete
  - These would be modules like buf, win, list, table, types
  - The goal is to avoid having to bounc between here and nvim-tools to make additions/changes
  - This would not include modules like treesitter, which I don't think are relevant here
- [ ] Meta-decisions created by nvim-tools need to be resolved
    * Examples: fdo handling, config resolution

#### TODO:

- [ ] The modules and code we want to continue with need a deeper audit.
  - [ ] Based on that audit, then extract the TODO info

- [ ] I believe that the goal with the _common module is to remove it.
- [ ] Because the whole plugin is moving to search based results, I think the lookup module just gets moved to nvim tools then removed.

- [ ] There are a lot of TODO items that I did not port over to here on account of not being sure how they all integrate together. I had tried a lot of different things in different files without really creating an integrated context for them.

- [ ] For unlimited tokens, use math.huge in the labeler and probably config. The way Lua does math works out for that.

- [ ] For live search at least, \ probably has to be blocked from being a token since it can be used for a regex atom. Probably makes sense to do that globally. In my original labeler comment, I noted that the labeler doesn't care about this, so this is something functions higher up the stack need to own.

- [ ] In all modules, add a "fold_cmd" option and remove fdo from the default callback
  - The default callback behavior was only done to maintain consistency with Neovim's default behavior
    * This is a bad behavior to be consistent with. What Neovim *should* provide is a keymap option to disable default fdo behavior
  - Handling fdo in the default callback is bad because, in certain cases, it might need to be performed in temporary window context. This should not be burden-shifted to the user
  - If running buf_open on a non-focused window, fdo needs to be run in temporary window context. This should not be burden-shfited to the user
    * This use case does not come up in farsight specifically, but I want to maintain consistency between my plugins
  - [ ] Document this reasoning in CONTRIBUTING.md
    - It feels like this is part of some bigger meta section on module design

- [ ] All APIs should be run through the init module
  - NOTE: A lot of this description might not matter based on how the config module turns out
  - This way, you can always do something like `require("farsight").csearch()`
  - Allows documentation to be centralized
  - [ ] Each API that runs through this module should have a sub-table in config
    - [ ] Then, as the APIs are added, edit the underlying functions to only grab the sub-table out of config once
    - [ ] Add this behavior to META or contributing
  - [ ] If a setting is not found in config, hard error
    - This should never happen
    - Getting default config is slow and adds complication
    - Default config can always be restored
    - This should prompt an issue to be filed
      * Counterpoint: The config would probably go bad due to a technical issue or user intervention unrelated to the particular API being used. So while the error would prompt looking into the issue, I'm not sure to what extent it would be of direct diagnostic value
      * [ ] This means that errors getting config need to present good information, including if the value is missing or if the value has a bad type
    - [ ] If a buf config value is missing, fall back to config. If a buf config value has a bad data type, hard error.

- [ ] Figure out final names for live and static jumping
  - I'm not sure they are clearly branded for the end user
  - Bad ideas:
    * Incremental does not work because both are incremental
    * Basing on token count does not work because static jumps can be customized to be single-token
  - Ideas:
    * live: Like lightspeed/flash/sneak. Should imply disappearing and re-appearing quickly
      + teleport
    * static: Like EasyMotion/Jump2D. Should imply the path being laid out before you.
      + vista

- [ ] Add `desc` values to Plug and default mappings
- [ ] Verify that the `require("farsight")` call in /plugin.lua does not require other files

- [ ] Rename everything to target locator branding

#### NON:

## Config

#### TODO:

- [ ] Options:
  - [ ] set_default_maps
  - [ ] Function specific options
    - [ ] csearch
    - [ ] static
    - [ ] live

## Csearch

#### TODO:

- [ ] Move this over to search based, where you iterate through the results then to find tokens
- [ ] Move this module over to the highlight on f/t model that a lot of other plugins use. I need the ;, keys to map live search.
  - [ ] Still keep the "classic" behavior as an option
  - [ ] Unlike flash, do not do continuation mode in omode or after a dot repeat
- [ ] For defaults, need to test if "\k" or "\k\+" is faster
- [ ] A problem to deal with is that if you set a custom search function based on whole words, you might get results that are excluded from targets because they start before the cursor. I'm not sure if search should compensate for this or if it needs to be a documented limitation
  - Since search is being generalized, probably needs to be handled

#### NON:

- [ ] Sneak mode. Don't need/want it with live jumps, don't want to make an inferior version of the original.

#### DOCUMENT:

- [ ] For search string customization, a possible use case would be to set search strings based on filetype. If that use case exists, show an example of using an autocmd to set buf_config based on filetype

## Live Search

## Static Jump

#### MID:

- [ ] An optimization could be - For each window being searched, get the buf info and buf ranges beforehand. See if there are any intersections. If so, only search the intersected area once.
  - [ ] Challenges:
    - [ ] How do you check for intersections?
      - I'm not sure what the solution is other than, after getting each window's range, to do an O(n*n) search through all of them
    - [ ] How do you store the intersections?
      - Maybe as an `[integer[], results]` where integer is the list of windows it applies to
    - [ ] How do you stitch the intersections back into the targets?
      - You have to see which set of targets goes after the other, so that the targets after can be appended to the ones before. Inserting at the beginning is too slow
      - Has to be done in a way so that a reference isn't accidentally modified that is meant to be re-used
