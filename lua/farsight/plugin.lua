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

---@type table<string, fun(opts: farsight.jump.JumpOpts)>
local actions_forward = {

    ["\r"] = function()
        require("farsight.jump").jump({ all_wins = false, dir = 1 })
    end,
}

---@type table<string, fun(opts: farsight.jump.JumpOpts)>
local actions_backward = {

    ["\r"] = function()
        require("farsight.jump").jump({ all_wins = false, dir = -1 })
    end,
}

local plugs = {
    {
        { "n" },
        "<Plug>(Farsight-Jump-Normal)",
        function()
            require("farsight.jump").jump({ wins = api.nvim_tabpage_list_wins(0) })
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

-- LOW: Is there a good way to allow jump's locator and wins opts to be controlled by g:vars?
-- - Changing either default would break vmode and omode
-- - Passing the built-in default expliclty breaks the assumption that g:vars overwrite defaults
