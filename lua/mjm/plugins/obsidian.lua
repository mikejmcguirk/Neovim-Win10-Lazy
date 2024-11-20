return {
    "epwalsh/obsidian.nvim",
    version = "*",
    dependencies = {
        "nvim-lua/plenary.nvim",
    },
    config = function()
        require("obsidian").setup({
            workspaces = {
                {
                    name = "main",
                    path = "~/obsidian/main",
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
            disable_frontmatter = true, -- The aliasing creates inconsistent behavior with the GUI
            -- Use the note title as the filename
            -- I would like to validate that the filename is valid on Windows, but I can't because
            -- cmp uses this when autocompleting [[]] bracket names
            note_id_func = function(title)
                if title ~= nil then
                    return title
                else
                    return nil -- This makes the LSP complain, but I want the error
                end
            end,
        })

        -- TODO: Create a map with [o and ]o that advances to the next/previous file in a folder
        vim.keymap.set("n", "<cr>", "<cmd>ObsidianFollowLink<cr>")
        vim.keymap.set("n", "<leader>ta", "<cmd>ObsidianBacklinks<cr>")
        vim.keymap.set("n", "<leader>tn", "<cmd>ObsidianLinks<cr>")
        vim.keymap.set("n", "<leader>sr", "<cmd>ObsidianRename<cr>")
    end,
}
