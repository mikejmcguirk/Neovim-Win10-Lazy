return {
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
                    local gs = require("gitsigns")

                    vim.keymap.set("n", "]c", function()
                        if vim.wo.diff then
                            vim.api.nvim_exec2("silent norm! ]c", {})
                        else
                            gs.nav_hunk("next")
                        end
                    end, { silent = true })
                    vim.keymap.set("n", "[c", function()
                        if vim.wo.diff then
                            vim.api.nvim_exec2("silent norm! [c", {})
                        else
                            gs.nav_hunk("prev")
                        end
                    end, { silent = true })

                    vim.keymap.set("n", "<leader>hd", gs.diffthis)
                    vim.keymap.set("n", "<leader>hp", gs.preview_hunk)
                    vim.keymap.set("n", "<leader>hr", gs.reset_hunk)
                    vim.keymap.set("n", "<leader>hS", gs.stage_buffer)
                    vim.keymap.set("n", "<leader>hi", gs.preview_hunk_inline)

                    vim.keymap.set({ "o", "x" }, "ih", gs.select_hunk)
                end,
            })
        end,
    },
}
