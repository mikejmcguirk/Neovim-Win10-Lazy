-- TODO: Might replace with org mode but will keep for now
local note_path = vim.fn.expand("~") .. "/notes/*.md"
return {
    "epwalsh/obsidian.nvim",
    version = "*",
    lazy = true,
    event = {
        "BufReadPre " .. note_path,
        "BufNewFile " .. note_path,
    },
    dependencies = {
        "nvim-lua/plenary.nvim",
    },
    config = function()
        require("obsidian").setup({
            workspaces = {
                {
                    name = "notes",
                    path = "~/notes",
                },
            },
            completion = {
                nvim_cmp = true,
                min_chars = 1,
            },
            mappings = {},
            ui = {
                enable = false,
            },
        })

        vim.keymap.set("n", "<cr>", "<cmd>ObsidianFollowLink<cr>")
        vim.keymap.set("n", "<leader>ta", "<cmd>ObsidianBacklinks<cr>")
        vim.keymap.set("n", "<leader>tn", "<cmd>ObsidianLinks<cr>")
        vim.keymap.set("n", "<leader>sr", "<cmd>ObsidianRename<cr>")
    end,
}
