local api = vim.api

local function setup_treesj()
    require("treesj").setup({
        use_default_keymaps = false,
        max_join_length = 99,
        notify = false,
    })

    vim.keymap.set("n", "gs", require("treesj").toggle)
    vim.keymap.set("n", "gS", function()
        require("treesj").split({ split = { recursive = true } })
    end)
end

local langs = require("treesj.langs").configured_langs
local load_treesj = api.nvim_create_augroup("load-treesj", {})
api.nvim_create_autocmd("FileType", {
    group = load_treesj,
    pattern = langs,
    callback = function()
        setup_treesj()
        api.nvim_del_augroup_by_id(load_treesj)
    end,
})
