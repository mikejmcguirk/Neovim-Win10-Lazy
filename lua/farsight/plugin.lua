vim.g.farsight_debug = true
-- TODO: Document highlight groups here
-- TODO: Document g:vars here. Check validations

-- TODO: Create checkhealth
-- - Nvim version
-- - g:var validity checks
-- - maparg success

local api = vim.api
local fn = vim.fn

local plugs = {
    {
        { "n", "x", "o" },
        "<Plug>(Farsight-Jump)",
        function()
            require("farsight.jump").jump({})
        end,
    },
    {
        { "n", "x", "o" },
        "<Plug>(Farsight-CsearchF-Forward)",
        function()
            require("farsight.csearch").csearch({})
        end,
    },
    {
        { "n", "x", "o" },
        "<Plug>(Farsight-CsearchF-Reverse)",
        function()
            require("farsight.csearch").csearch({ forward = 0 })
        end,
    },
    {
        { "n", "x", "o" },
        "<Plug>(Farsight-CsearchT-Forward)",
        function()
            require("farsight.csearch").csearch({ ["until"] = 1 })
        end,
    },
    {
        { "n", "x", "o" },
        "<Plug>(Farsight-CsearchT-Reverse)",
        function()
            require("farsight.csearch").csearch({ forward = 0, ["until"] = 1 })
        end,
    },
    {
        { "n", "x", "o" },
        "<Plug>(Farsight-CsearchRep-Forward)",
        function()
            require("farsight.csearch").rep({})
        end,
    },
    -- TODO: Should reverse also be used as the naming convention for the plugs?
    {
        { "n", "x", "o" },
        "<Plug>(Farsight-CsearchRep-Reverse)",
        function()
            require("farsight.csearch").rep({ forward = 0 })
        end,
    },
}

local len_plugs = #plugs
for i = 1, len_plugs do
    local plug = plugs[i]
    local modes = plug[1]
    local key = plug[2]
    local callback = plug[3]
    local len_modes = #modes
    for j = 1, len_modes do
        api.nvim_set_keymap(modes[j], key, "", { noremap = true, callback = callback })
    end
end

-- TODO: Loop up the mappings
-- TODO: I don't love the Csearch plug names
-- TODO: Need omode mappings for csearch. But need to add visual selection for it
-- Also note that the alternative actions should not be present

if vim.g.farsight_default_maps == false then
    return
end

---@type { [1]: string[], [2]: string, [3]: string }[]
local jump_maps = {
    { { "n", "x", "o" }, "<cr>", "<Plug>(Farsight-Jump)" },
}

for i = 1, #jump_maps do
    local map = jump_maps[i]
    local modes = map[1]
    local key = map[2]
    local rhs = map[3]
    for j = 1, #modes do
        local mode = modes[j]
        local maparg_res = fn.maparg(key, mode)
        -- Need to check for just <cr> because of unsimplification (:h <tab>)
        if maparg_res == "" or string.lower(maparg_res) == key then
            api.nvim_set_keymap(mode, key, rhs, { noremap = true })
        end
    end
end

---@type { [1]: string[], [2]: string, [3]: string }[]
local csearch_maps = {
    { { "n", "x", "o" }, "f", "<Plug>(Farsight-CsearchF-Forward)" },
    { { "n", "x", "o" }, "F", "<Plug>(Farsight-CsearchF-Reverse)" },
    { { "n", "x", "o" }, "t", "<Plug>(Farsight-CsearchT-Forward)" },
    { { "n", "x", "o" }, "T", "<Plug>(Farsight-CsearchT-Reverse)" },
    { { "n", "x", "o" }, ";", "<Plug>(Farsight-CsearchRep-Forward)" },
    { { "n", "x", "o" }, ",", "<Plug>(Farsight-CsearchRep-Reverse)" },
}

vim.b.farsight_default_maps = false

for i = 1, #csearch_maps do
    local map = csearch_maps[i]
    local modes = map[1]
    local key = map[2]
    local rhs = map[3]
    for j = 1, #modes do
        local mode = modes[j]
        if fn.maparg(key, mode) == "" then
            api.nvim_set_keymap(mode, key, rhs, { noremap = true })
        end
    end
end

-- Profiling code:
-- local start_time = vim.uv.hrtime()
-- local end_time = vim.uv.hrtime()
-- local duration_ms = (end_time - start_time) / 1e6
-- print(string.format("hl_forward took %.2f ms", duration_ms))

-- NOTE: Internal function locations:
-- - cursor() : f_cursor in funcs.c
-- - line() : f_line in funcs.c
-- - col() : f_col in funcs.c
-- - search() : f_search in funcs.c

-- NOTE: Outside of hot paths, it is okay to be redundant with validation. Promotes robustness.
-- For internal code (underline modules), do not validate what type annotations can catch.
-- NOTE: Unexpected but valid behaviors should be handled gracefully. Invalid behaviors should
-- hard error.

-- TODO: When the plugin is done, verify that only init.lua is required on startup.
-- TODO_DOC: Specifically note that the plugin does not eagerly require unnecessary modules and
-- is not meant to be lazy loaded.
-- TODO: Take the config ramble below and turn it into action items.
-- - Note: My opinions changed a lot as I was writing it
-- TODO: Want to think more seriously about config, because:
-- - It's becoming too many g/b vars
-- - The validation when running commands is non-trivially long
-- - For any option that takes a table, the metatable is lost. So for tokens, you would have to
-- totally re-assign tokens each time.
-- - If metatable vimvars worked, you couldn't use that validation method for non-table vars
-- - If you moved things to a config module (NOT setup), you could basically re-create the same
-- g:var interface that you would use if it existed.
-- - You could have a hash table for buf-scoped config
-- - This would, unfortunately, require the config module to be required when running
-- /plugin.
-- - The data validation would need to be moved into the config module so that it doesn't require
-- other modules
-- - I don't know how this would play with the "opts" key in lazy.nvim
-- - The config module would need a "did_initial_config" var so that it doesn't run twice
-- - Would probably make this the init.lua file so you can do require("farsight").config()
-- - During startup, I would make any validation failure simply revert to default. Then any
-- failed config change after should be a hard error
-- - For did_setup, if you pass a nil config table, it should rely on did_setup being false, and
-- maybe v:did_enter (NOT did_init) being false. As this will setup the initial config. Otherwise,
-- a new config should be required
-- - There are also questions to be asked about how to handle extra keys or non-existent keys
-- - You would still want to compare the buf config and global config  at execution time, since
-- that's how g: and b: would work
-- - As much as it would be intellectually interesting + future compatible to do something like
-- require("farsight").config = {} and use a metatable to parse it, this would be an anti-pattern.
-- So do:
--   - require("farsight").config({})
--   - require("farsight").buf_config(0, {})
--   - You could maybe use operator overloading to make buf an optional first argument
-- - There would need to be a way for the user to pass nil values to unset options back to defaults
--   - This raises the issue of, even if g/b metatables worked, would you get rid of the config
--   module at all, since it allows for centralization of common settings, like search timeout
--   - But then, a layer deeper, why does config need to run during plugin sourcing at all? The
--   one reason I can think of is that the user might not want to set default mappings, and it
--   makes more sense to check that with the config module. But I'm not sure config needs to be
--   run by default to check that. If the user wants to use config to disable plug mappings, they
--   can call it and and set that option, which would then set a g:var. But I'm not sure how this
--   works for lazy.nvim. You *can* tell the user to do it during init, but that's an anti-pattern.
--   I don't know if opts runs before /plugin or not.
-- - The merging procedure would roughly go
--   - Iterate through keys in the input table
--   - See if a default config key exists
--   - If it exists, validate the input
--   - If valid, in the active config, replace the key with the user key
--   - Problem: How do you attach specific validators like is_int to this? You could maintain a
--   parallel validators table with the same key structure as the default config, and fallback
--   to type validation. Feels unprincipled though. On the other hand, this basic idea is
--   compatible with g/b config. Since with that, you would want to set the metatable, on index,
--   to pull a validator with the same key. Like, how else would it find it? This also, again,
--   points toward just always requiring init on startup, since we need the validators to be
--   available.
-- - In the g/b config method, you would want the user to be able to assign the table + vars during
-- init, before plugin sourcing, which would create the more elaborate structures. In that case,
-- the /plugin script would need to read the pre-existing table data and properly merge it into
-- the default (replacing with default rather than erroring if it's bad). A similar thing should
-- happen here. The initial setup should be done on require. So if the user passes opts or runs
-- config() manually, it should have the same effect as described above (though the technical
-- ordering would be reversed). Again, this points to init.lua being required even with the g/b
-- method. So if we do all the stuff I'm talking about above, we aren't increasing startup time.
--   - This would eliminate the need for a contrived did_run_setup check when running config(),
--   since that function wouldn't handle initial setup. In the plugin file, you would just run
--   require("farsight") and that would do the initialization
--     - This also achieves the important conceptual goal of separating initialization and config.
--     Running config() might trigger initialization, but is not necessary to do so
--   - For validation behavior, you would just check v:did_enter (not did_init). You can defer
--   this check to validation failure so you don't have to run it frivolously
--   - This removes the weird question above about if config() has to be run during startup (it
--   doesn't, but the module does have to be required by /plugin). It also (should) remove the
--   timing question about running config. If the user runs it before /plugin does, /plugin
--   requiring it is essentially a no-op. No matter when the user runs it, initialization happens
--   first during the require step.
--   - Somewhat in reference to the external interface discussion above - The underlying buf config
--   table would still need to be some kind of accesor metatable that routed the inputs and
--   validation.
--     - Related to the above point and the current one, the validation logic would sit in the
--     init module so it could not be directly modified
-- - In the g/b method, something like vim.g.farsight = nil would be caught by the metatable and
-- considered a no-op. So with the config method, a nil config should be considered a request
-- to get a copy of the config table
--   - The question then is what does sending {} do? Is this a no-op or a full reset? If you pass
--   a table with only one opt in it, we would intuitively think that only that opt should be
--   changed. So then, intuitively, {} should do nothing.
--   - Setting an individual opt to nil should definitely reset that opt. But then this points to
--   a nil table pass being a request to reset, which then raises the question of how you get
--   the config. But get_config() is a much more common pattern in the Neovim space. And aligns
--   better with how g/b would be done (where you would read the variable, rather than assigning
--   to it). So this is actually the better pattern.
--     - {} does nothing
--     - nil resets
--       - In the g/b case, this does create the weird problem of never being able to remove the
--       config table. Though if you wanted to do that, for whatever reason, then I think you
--       would run setmetatable on it with a nil metatable value.
--     - use get_config() to get (would produce a deepcopy)
--   - Resetting the buf config would delete it from memory
-- - As a side note, all of this would apply to and greatly help rancher. Would need to think
-- about it if helps lampshade.
-- - A question then is how do you reason about and do the class definitions for the opts tables
-- that are partially drawn from config (like timeout) and determined purely at runtime (like
-- csearch forward).
--   - More fundamentally, what about user_input vs. the default table? The input class needs the
--   fields to all be optional. The actual default fields need to be mandatory.
-- - You could also have functions like get_default_config and get_config_diff to see the
-- differences between the default and current. You could also pass a bufid to get_config_diff
-- to see the per-buffer difference.
--   - Per-buf config vs. default and per-buf config vs. global config are different things and
--   that needs to be accounted for.
--     - Have the first opt? be bufid, and the second opt? be "default"|"global". nil bufid and
--     "global" would return {}. And we put the silliest case on the most unintuitive set of
--     params.
--       - bufid 0 needs to resolve manually (true of writes as well)
--       - something mildly clever you can do is, if you try to get buf config for an invalid buf,
--       the bufs config table for that buf should be nil'd just in case
--       - Not entirely sure what to do though on an invalid buf. A hard error feels like too much
--       since it's not invalid user input. But putting it behind an ok pattern feels weird.
--       Actually though it's simple. If the buf is valid but there's no buf config, return an
--       empty table, adding one to the internal bufs table if it doesn't exist. If the buf is
--       invalid, return nil. Make sure that's reflected in the return type.
-- - Use an autocmd to remove buf configs when the buf closes
-- - An nvim-tools version of the config file should be created. Write this one first though
-- so we have a concrete use case.
-- - All of this also makes API changes/deprecation easier.
--   - The deprecation handling methods for opts keys and plug maps should be generalizable such
--   that they can be included in the generalized nvim-tools version of the config
--   - Write up an internal version of this that's actually professional, but don't actually
--   publish unless the plugin gets a real user base. The plugin can be experimental while it
--   has a small number of users.
--   - Opts keys
--     - Soft-launch
--       - NOT a breaking change
--       - New opts keys work immediately
--       - The old key is still documented, but with the note that it will be deprecated
--       - The plugin internals assume the old key is not there
--       - When adding a key, the current keys are checked. If the key is not found, then old_keys
--       is checked. If the key is found in old_keys, the behavior is routed to the new key. This
--       happens transparently
--         - It would be useful if this phase allowed the old key to work as normal with the new
--         key potentially sitting on top of it. This would allow changes to be made to the new
--         key if needed/wanted. The problem is, the way I have it now, this allows the old_keys
--         checking to be modularized so, say, config and JumpOpts could both use it. I'm not sure
--         if that's possible if you base it on new_keys. Would need to think about the
--         super/subsets this needs to address though
--     - Deprecation phase
--       - Breaking change
--       - The docs now state that the old key is deprecated. It states no info on how to use it
--       and instead refers to the new key.
--       - When the old key is found in old_keys, vim.deprecate is called. It cannot be silenced
--         - If, somehow, a use case comes up where like, another plugin is built on top of this
--         that uses the deprecated key and it can't be changed, this can be revisited. But,
--         unlike vim.deprecate notices for plugins, where you're at the mercy of the plugin
--         author, in this case, you can just change the key.
--     - Deletion
--       - Breaking change
--       - The class definitions and old_keys routing are completely removed
--       - The old key is a no-op
--   - API replacement (Deletion is the same, just without the new function)
--     - Soft launch
--       - Not breaking
--       - The replacement is available, the old one is documented as future deprecation
--     - Deprecation
--       - Breaking
--       - The old function calls vim.deprecate. The documentation only states that it is
--       deprecated and refers to the new function.
--     - Deletion
--       - breaking
--       - The old function is deleted from the code and docs
--   - API change
--     - Soft launch
--       - Not breaking
--       - The public interface is a shim that routes between the old and new functions based on
--       the signature
--       - The new interface is documented. The old interface is still documented but marked as
--       future deprecation
--     - Deprecation
--       - Breaking
--       - When the old signature is seen, vim.deprecate is called
--       - The datatypes of the old signature are documented, but only with a deprecation notice
--     - Deletion
--       - Breaking
--       - The public interface becomes the new function. The old one is removed from the docs.
--       vim.validate assumes the new interface.
--   - Plug mappings
--     - (Note: There is nothing wrong with keeping alternative Plug mappings around so long as
--     they are separate from the defaults)
--     - Soft launch
--       - Not breaking
--       - Replacement plug mapping is available and documented
--       - The documentation for the old plug notes that it will be deprecated
--       - If config.use_uptodate_plugs is true (note: default should be false), the new one is
--       mapped instead. The user can disable the opt or manually revert.
--     - Deprecation phase
--       - Breaking
--       - The replacement plug is is available and mapped
--       - The old plug is available but not mapped. The doc for the old Plug only states that it
--       is deprecated without additional info
--       - The user can manually re-map the old plug if they wish
--     - Deletion
--       - Breaking
--       - The old plug mapping is removed from the code and documentation
-- TODO: For the APIs, do you do something like put a wrapper for static in init.lua that calls
-- the underlying file? Would have following benefits:
-- - More intuitive user interface. require("farsight").live()
-- - Since all API calls are in one module, all documentation can go in there.
--   - This also removes the "organizaing modules for documentation" problem, which had become
--   a non-trivial strain.
-- - Since all opt data needs to be validated, it could use the validation functions already in
-- init.lua. Then the underlying modules could solely handle data resolution
--   - It is somewhat of a weird question why you would not do resolution in the shim. But I think,
--   for robustness, the underlying modules should handle it. This still maintains conceptual
--   clarity between validation and resolution.
-- - If the config module, which we're requiring anyway, also contains the API shims, this means
-- the keymaps can be set without wrapping the functions in anonymous functions. This is a major
-- help for Lua_Ls as well as the code being less obnoxious to read.
--   - Counterpoint: Is this non-trivially slower to actually execute?
--   - Counterpoint: Since a lot of opts are things like forward in csearch, you don't *really* get
--   this advantage.
-- Downsides
-- - The class definitions for the user-facing options would need to go into init so they could
-- be documented. Not great from an ownership perspective
-- TODO: I think "nomap_ft", "nomap_live", and "nomap_static" options are fine. We presume that
-- "nomap_all" overrides any of them.
-- TODO: I believe the manual isk checking will be completely obsoleted from this plugin. I think
-- that code, along with the various other components in here and in rancher, justify creating an
-- nvim-tools repo. Each module should have an error message at the top of it so it cannot be
-- required. We do not want to create a new plenary.
-- TODO: Note mainly for jumping and csearch:
-- - \k matches individual characters
-- - \<\k\+\> ensures word boundaries are respected
-- - \k\+ looks for runs but does not respect word boundaries
-- Feels better to use the word boundary one so that way static jump uses proper boundaries when
-- creating labels
-- TODO: Look at how stevearc/folke do their docgen. Manually keeping up the README has been a
-- major pain point with Rancher and even lampshade.
-- TODO: Config points: Overall, csearch, live search, static search
-- TODO: I *think* I want to ship a static jump as default on enter. Show all three features.
-- - That said, for posterity, do explore a live jump on multiple windows as a default. Test in
-- dense code windows. My question is if there are too many results for labels to reliably spawn
-- after a small number of keypresses.
-- - For static jump, IMO labels at beginning only is the sanest default, but test "both" as well.
-- TODO: See if dim rows in csearch and jump can be handled like in search
-- TODO: For any jumps, if doing a backwards correction for omode, use cursor() instead of the API
-- because it doesn't trigger a screen update.
-- - Or is this based on search() now? Haven't looked at that code in a while.
-- TODO: Functionalities to try putting into common
-- - Dimming. Could have a function that takes a row list, ns, and hl_group and runs through
-- setting the extmarks. Also have it take a dim opt
-- - At least some of the logic for getting the wrapped bottom row. It's all checking the opt
-- and searchpos on the first col.
-- TODO: Replace vim.fn with vim.call where possible
-- TODO: Confirm that g/b:vars can take function literals. I've seen it work, but does it break?
-- TODO: Where can we use require("table.new")?
-- TODO: Document that, in all cases, |cpo-c| is respected. Sub-note though that the default
-- jump pattern explicitly uses word boundaries to avoid overlaps
-- TODO: The various functions should have hard protections against multi-win if not in normal mode
-- TODO: Document deprecation plan:
-- - Time period: 2-3 months
-- - Opt/function removal: Mark private/package, then delete
-- - Function signature change: Use a shim that routes the old interface, then delete the shim and
-- old interface
-- - Default function behaviors: Notify which opt lets you use old behavior
-- - Plug map changes: Unsure
-- TODO_DOC: b:vars are the same as g:vars and prioritized. Can be used for ft configurations
-- TODO: Test everything with and around multibyte chars. It doesn't look like anything special
-- needs to be done, but need to be sure
-- TODO: Need to test that the gb options work
-- TODO: Jokes:
-- - "Extraterrestrial vantage point over your code"
-- - "You'll move through your code so quickly, people won't be sure your movement was real"
-- - "See through walls with jump" (Direct Farsight reference)
-- - "Even the best researchers at Area 51 won't be able to understand your speed"
-- TODO: Re-check that farsight name is available
-- TODO: README:
-- - Credits:
--   - jump2d (initial basis for jump)
--   - flash/lightspeed/leap (for the incremental jump idea)
-- - Inspirations:
--   - Quickscope
-- - Alternatives:
--   - vim-sneak
--   - hop
--   - EasyMotion
--   - { Flash lists a lot of them }
-- - TODO: Create docgen
-- - TODO: Go through the opts of the various functions and document the g:variable overrides

-- TODO_DOC: I don't know how much of this is internal vs. user-facing documentation, but - The
-- general attitude toward any Puc Lua compatibility function should be: It should handle typical
-- cases, and effort might be made to support edge cases, but the design of the overal module
-- cannot be compromised to handle it. LuaJIT support/performance takes priority.

-- LOW: Remove invisible targets. All methods I know to do this have problems:
-- - screenpos() - Non-trivially slow
-- - strcharlen() + strdisplaywidth() - Likely also slow
-- - Hand-rolling Lua functions - Non-trivially difficult to write and maintain
-- Other issues
-- - Efficiently removing characters under floats
-- - Determining string length for the wrapped fill line
-- - Removing characters under listchars, plus under "@@@" in wrapped lines
-- Hard to prioritize because it does not cause false negatives
-- LOW: Evaluate target closeness by euclidian distance rather than row/col order.
-- LOW: For folds: first_row - Display virtual text on top of the fold and label the virtual text
-- with all the options.
--
-- PR: The end_row key in nvim_buf_set_extmark appears to be exclusive when using the hl_eol
-- option, but this is not mentioned in the docs. Verify if this intuition is correct and submit
-- a PR if so

-- ISSUE: Search does not properly consider multiline boundaries for searching after.
-- Reproduction:
-- - Open nvim clean
-- - confirm cpo c is set (is default in Neovim)
-- - Have "foo" on 15 lines
-- - Search "foo\nfoo" then enter
-- - hlsearch will correctly show the current search as two lines since cpo-c is true. However,
-- when hitting n to advance searches, it will go to the next line
-- - If incsearch is true, more weird stuff happens with how the current search increments.
-- Sometimes it's properly two lines, sometimes it shows three. Need to play with this behavior
-- more.
-- Additional questions:
-- - This needs to be tested in vanilla Vim since it's a vimfn. The issue needs to be opened there
-- if it happens there
-- - Why does hlsearch display properly? (At least in Neovim). Given the issue where hlsearch
-- always displays with cpo-c behavior, it appears there is some non-trivial code difference
-- - Is an issue already open? (Check both repos)
-- Possible cause:
-- search.c line 722:
--   if (search_from_match_end) {
--     if (nmatched > 1) {
--       // end is in next line, thus no match in
--       // this line
--       match_ok = false;
--       break;
--     }
--     matchcol = endpos.col;
--     // for empty match: advance one char
--     if (matchcol == matchpos.col && ptr[matchcol] != NUL) {
--       matchcol += utfc_ptr2len(ptr + matchcol);
--     }
--     // ...
--   }
-- matchcol is advanced, but lnum is not. But simply advancing lnum could be tricky, since it's
-- the control variable for the main search loop.
-- ISSUE: Weird hlsearch behavior.
-- Reproduction (need to confirm in minimal Neovim):
-- - Open nvim clean
-- - Confirm cpo c is off (needs to be set in Neovim)
-- - "foofoofoofoofoofoofoofoofoofoofoofoofoofoofoo"
-- - /foofoo
-- - At first match, press n
-- - First three foos highlighted
-- - Have "foo" on 15 consecutive lines
-- - /foo\nfoo<cr>
-- - The last "foo" will not be highlighted as if cpo c were present
-- Additional questions:
-- - Does this happen in vanilla vim?
-- - Is an issue already open? (Check Vim and Nvim repos)

-- FUTURE: If vim vars are able to properly hold metatables, use them for var validation
-- FUTURE: Use the new mark API when it comes out for setting pcmarks
