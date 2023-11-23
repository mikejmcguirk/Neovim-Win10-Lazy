return {
    {
        "tpope/vim-fugitive",
    },
    {
        "lewis6991/gitsigns.nvim",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            require("gitsigns").setup({
                signs = {
                    add = { text = "+" },
                    change = { text = "~" },
                },
                on_attach = function(bufnr)
                    local gs = package.loaded.gitsigns

                    vim.keymap.set("n", "[g", function()
                        if vim.wo.diff then
                            return "[g"
                        end

                        vim.schedule(function()
                            gs.prev_hunk()
                        end)

                        return "<Ignore>"
                    end, { expr = true })

                    vim.keymap.set("n", "]g", function()
                        if vim.wo.diff then
                            return "]g"
                        end

                        vim.schedule(function()
                            gs.next_hunk()
                        end)

                        return "<Ignore>"
                    end, { expr = true })

                    -- Actions
                    vim.keymap.set("n", "<leader>gsb", gs.stage_buffer)
                    vim.keymap.set("n", "<leader>gd", gs.diffthis)

                    -- Text object
                    vim.keymap.set({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>")
                end,
            })
        end,
    },
}
