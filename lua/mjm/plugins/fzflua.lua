return {
    "ibhagwan/fzf-lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {},
    config = function()
        -- Undo history (as well as restore)
        -- How to see key help
        -- Border/aesthetic config
        -- The qf and loclist stacks are very interesting, and unlock those features

        local fzf_lua = require("fzf-lua")
        vim.keymap.set("n", "<leader>ff", fzf_lua.resume)
        vim.keymap.set("n", "<leader>fi", fzf_lua.files)
        vim.keymap.set("n", "<leader>fb", fzf_lua.buffers)
    end,
}
