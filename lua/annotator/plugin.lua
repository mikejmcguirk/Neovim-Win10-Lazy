local api = vim.api

-- TODO: This feels roughly like the template for docgen, but would need to think more about
-- what is being put into here and how the docgen can extract it. Because this plugin is fairly
-- low priority, this probably won't be the test case either.
-- A weird question actually is, *can* you put the maps into /plugin if you use the docgen? I
-- guess you can, you just need to have custom module headers.
---@type [string[], string, string|nil, function][]
local plug_maps = {
    {
        { "n" },
        "<Plug>(annotator-add-mark)",
        nil,
        function()
            require("annotator").add_annotation()
        end,
    },
    {
        { "n" },
        "<Plug>(annotator-add-borders)",
        nil,
        function()
            require("annotator").add_borders()
        end,
    },
    {
        { "n", "x" },
        "<Plug>(annotator-jump-rev)",
        "[k",
        function()
            require("annotator").jump(-1)
        end,
    },
    {
        { "n", "x" },
        "<Plug>(annotator-jump-fwd)",
        "]k",
        function()
            require("annotator").jump(1)
        end,
    },
}

local len_plug_maps = #plug_maps
for i = 1, len_plug_maps do
    local plug_map = plug_maps[i]
    local modes = plug_map[1]
    local len_modes = #modes
    for j = 1, len_modes do
        local mode = modes[j]
        api.nvim_set_keymap(mode, plug_map[2], "", {
            noremap = true,
            callback = plug_map[4],
        })
    end
end

local annotator = require("annotator")
local config = annotator.config()

-- TODO: This should be some kind of table so that multiple modes can be handled.
if config.create_plug_integrations then
    api.nvim_set_keymap("n", "<Plug>(annotator-fzf-lua-grep-curbuf)", "", {
        noremap = true,
        callback = function()
            annotator.fzf_lua_grep(true)
        end,
    })

    api.nvim_set_keymap("n", "<Plug>(annotator-fzf-lua-grep-curbuf-luacats)", "", {
        noremap = true,
        callback = function()
            annotator.fzf_lua_grep_luacats(true)
        end,
    })

    api.nvim_set_keymap("n", "<Plug>(annotator-fzf-lua-grep-cwd)", "", {
        noremap = true,
        callback = function()
            annotator.fzf_lua_grep(false)
        end,
    })

    api.nvim_set_keymap("n", "<Plug>(annotator-rancher-grep-curbuf)", "", {
        noremap = true,
        callback = function()
            annotator.rancher_grep(true)
        end,
    })

    api.nvim_set_keymap("n", "<Plug>(annotator-rancher-grep-cwd)", "", {
        noremap = true,
        callback = function()
            annotator.rancher_grep(false)
        end,
    })
end

if config.set_default_maps == false then
    return
end

for i = 1, len_plug_maps do
    local plug_map = plug_maps[i]
    local default = plug_map[3]
    if default then
        local modes = plug_map[1]
        local len_modes = #modes
        for j = 1, len_modes do
            local mode = modes[j]
            api.nvim_set_keymap(mode, default, plug_map[2], { noremap = true })
        end
    end
end
