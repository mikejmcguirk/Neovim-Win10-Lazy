local api = vim.api

api.nvim_set_keymap("n", "<Plug>(annotator-add-mark)", "", {
    noremap = true,
    callback = function()
        require("annotator").add_annotation()
    end,
})

api.nvim_set_keymap("n", "<Plug>(annotator-add-borders)", "", {
    noremap = true,
    callback = function()
        require("annotator").add_borders()
    end,
})

local annotator = require("annotator")

api.nvim_set_keymap("n", "<Plug>(annotator-jump-rev)", "", {
    noremap = true,
    callback = function()
        annotator.jump(-1)
    end,
})

api.nvim_set_keymap("n", "<Plug>(annotator-jump-fwd)", "", {
    noremap = true,
    callback = function()
        annotator.jump(1)
    end,
})

local config = annotator.config()

if config.create_plug_integrations then
    api.nvim_set_keymap("n", "<Plug>(annotator-fzf-lua-grep-curbuf)", "", {
        noremap = true,
        callback = function()
            annotator.fzf_lua_grep(true)
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

if config.set_default_maps == true then
    api.nvim_set_keymap("n", "[k", "<Plug>(annotator-jump-rev)", { noremap = true })
    api.nvim_set_keymap("n", "]k", "<Plug>(annotator-jump-fwd)", { noremap = true })
end
