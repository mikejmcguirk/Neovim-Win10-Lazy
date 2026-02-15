-- TODO: I'm not sure validating opts here is actually valuable. checkhealth should fulfill this
-- purpose, and bad g:vars will fail validation if used. Avoids requiring util here

-- TODO: Document highlight groups here

-- TODO: Document g:vars here:
-- - farsight_dim
-- - farsight_keepjumps
-- - farsight_max_tokens
-- - farsight_on_jump
-- - farsight_tokens

-- TODO: Create checkhealth
-- - Nvim version
-- - g:var validity checks
-- - maparg success

local api = vim.api
local fn = vim.fn
local lower = string.lower
local maparg = fn.maparg
local set = api.nvim_set_keymap

-- TODO: Is the opts typing here right?

---@type table<string, fun(opts: farsight.jump.JumpOpts)>
local actions_forward = {

    ["\r"] = function()
        require("farsight.jump").jump({ dir = 1 })
    end,
}

---@type table<string, fun(opts: farsight.jump.JumpOpts)>
local actions_backward = {

    ["\r"] = function()
        require("farsight.jump").jump({ dir = -1 })
    end,
}

local plugs = {
    {
        { "n" },
        "<Plug>(Farsight-Jump-Normal)",
        function()
            require("farsight.jump").jump({})
        end,
    },
    {
        { "x" },
        "<Plug>(Farsight-Jump-Visual)",
        function()
            require("farsight.jump").jump({})
        end,
    },
    {
        { "o" },
        "<Plug>(Farsight-Jump-Operator-Pending)",
        function()
            require("farsight.jump").jump({})
        end,
    },
    {
        { "n", "x", "o" },
        "<Plug>(Farsight-CsearchF-Forward)",
        function()
            require("farsight.csearch").csearch({ actions = actions_forward })
        end,
    },
    {
        { "n", "x", "o" },
        "<Plug>(Farsight-CsearchF-Backward)",
        function()
            require("farsight.csearch").csearch({ actions = actions_backward, forward = 0 })
        end,
    },
    {
        { "n", "x", "o" },
        "<Plug>(Farsight-CsearchT-Forward)",
        function()
            require("farsight.csearch").csearch({ actions = actions_forward, t_cmd = 1 })
        end,
    },
    {
        { "n", "x", "o" },
        "<Plug>(Farsight-CsearchT-Backward)",
        function()
            require("farsight.csearch").csearch({
                actions = actions_backward,
                forward = 0,
                t_cmd = 1,
            })
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
        "<Plug>(Farsight-CsearchRep-Backward)",
        function()
            require("farsight.csearch").rep({ forward = 0 })
        end,
    },
}

for _, map in ipairs(plugs) do
    for _, mode in ipairs(map[1]) do
        set(mode, map[2], "", { noremap = true, callback = map[3] })
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
    { { "n" }, "<cr>", "<Plug>(Farsight-Jump-Normal)" },
    { { "x" }, "<cr>", "<Plug>(Farsight-Jump-Visual)" },
    { { "o" }, "<cr>", "<Plug>(Farsight-Jump-Operator-Pending)" },
}

for _, map in ipairs(jump_maps) do
    for _, mode in ipairs(map[1]) do
        local key = map[2]
        local maparg_res = maparg(key, mode)
        -- Need to check for just <cr> because of unsimplification (:h <tab>)
        if maparg_res == "" or lower(maparg_res) == key then
            set(mode, key, map[3], { noremap = true })
        end
    end
end

---@type { [1]: string[], [2]: string, [3]: string }[]
local csearch_maps = {
    { { "n", "x", "o" }, "f", "<Plug>(Farsight-CsearchF-Forward)" },
    { { "n", "x", "o" }, "F", "<Plug>(Farsight-CsearchF-Backward)" },
    { { "n", "x", "o" }, "t", "<Plug>(Farsight-CsearchT-Forward)" },
    { { "n", "x", "o" }, "T", "<Plug>(Farsight-CsearchT-Backward)" },
    { { "n", "x", "o" }, ";", "<Plug>(Farsight-CsearchRep-Forward)" },
    { { "n", "x", "o" }, ",", "<Plug>(Farsight-CsearchRep-Backward)" },
}

for _, map in ipairs(csearch_maps) do
    for _, mode in ipairs(map[1]) do
        local key = map[2]
        local maparg_res = maparg(key, mode)
        -- MID: Unsure if we should check for the literal mapped key here. What is the use case we
        -- are intentionally overwriting?
        if maparg_res == "" or maparg_res == key then
            set(mode, key, map[3], { noremap = true })
        end
    end
end

-- Profiling code:
-- local start_time = vim.uv.hrtime()
-- local end_time = vim.uv.hrtime()
-- local duration_ms = (end_time - start_time) / 1e6
-- print(string.format("hl_forward took %.2f ms", duration_ms))

-- TODO: Document that for csearch and /? search that |cpo-c| is respected
-- TODO: Add types to any usages of matchstrpos
-- TODO: The various functions should have hard protections against multi-win if not in normal mode
-- TODO: Augmented /? search. Design specs:
-- - As you are typing, items are labeled like in flash
-- - If you jump to a label, the "/" register is not updated
-- - If you hit <cr>, the "/" register is updated and hlsearch is turned on based on settings
-- - No auto-jump, as (a) this can happen by accident and (b) it can prevent entering full search
-- terms for actual searches
-- Design plan:
-- - Look at the code for search and note what it actually does. There is nuance I'm sure we'll
-- need to capture
-- - Look at what happens when "incsearch" is active. How much do we want to implement that
-- behavior?
-- - For the actual search, try to use the search() function or something related, as it uses the
-- same underlying searchit function that /? search uses
-- TODO: Document deprecation plan:
-- - Time period: 2-3 months
-- - Opt/function removal: Mark private/package, then delete
-- - Function signature change: Use a shim that routes the old interface, then delete the shim and
-- old interface
-- - Default function behaviors: Notify which opt lets you use old behavior
-- - Plug map changes: Unsure
-- Document that b:vars are the same as g:vars and prioritized. Can be used for ft configurations
-- TODO: Test everything with and around multibyte chars. It doesn't look like anything special
-- needs to be done, but need to be sure
-- TODO: Since ctrl char literals are displayed, maybe allow them to be factored into csearch and
-- jump
-- TODO: Need to test that the gb options work
-- TODO: Jokes:
-- - "Extraterrestrial vantage point over your code"
-- - "You'll move through your code so quickly, people won't be sure your movement was real"
-- - "See through walls with jump" (Direct Farsight reference)
-- - "Even the best researchers at Area 51 won't be able to understand your speed"

-- LOW: Is there a good way to allow jump's locator and wins opts to be controlled by g:vars?
-- - Changing either default would break vmode and omode
-- - Passing the built-in default expliclty breaks the assumption that g:vars overwrite defaults

-- FUTURE: If vim vars are able to properly hold metatables, use them for var validation

-- PR: Understand how matchstrpos's returns actually work and update them in eval.lua
