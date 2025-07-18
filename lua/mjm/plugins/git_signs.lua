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
                    local gitsigns = require("gitsigns")
                    local function map(mode, l, r, opts)
                        opts = opts or {}
                        opts.buffer = bufnr
                        vim.keymap.set(mode, l, r, opts)
                    end

                    map("n", "]c", function()
                        if vim.wo.diff then
                            vim.cmd.normal({ "]c", bang = true })
                        else
                            gitsigns.nav_hunk("next", { greedy = true })
                        end
                    end)

                    map("n", "[c", function()
                        if vim.wo.diff then
                            vim.cmd.normal({ "[c", bang = true })
                        else
                            gitsigns.nav_hunk("prev", { greedy = true })
                        end
                    end)

                    map("n", "]h", function()
                        if vim.wo.diff then
                            vim.cmd.normal({ "]c", bang = true })
                        else
                            gitsigns.nav_hunk("next", { greedy = true, target = "staged" })
                        end
                    end)

                    map("n", "[h", function()
                        if vim.wo.diff then
                            vim.cmd.normal({ "[c", bang = true })
                        else
                            gitsigns.nav_hunk("prev", { greedy = true, target = "staged" })
                        end
                    end)

                    -- NOTE: stage_hunk is also undo stage
                    map("n", "<leader>hs", gitsigns.stage_hunk)
                    map("n", "<leader>hr", gitsigns.reset_hunk)

                    map("v", "<leader>hs", function()
                        gitsigns.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
                    end)

                    map("v", "<leader>hr", function()
                        gitsigns.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
                    end)

                    map("n", "<leader>hS", gitsigns.stage_buffer)
                    map("n", "<leader>hR", gitsigns.reset_buffer)
                    map("n", "<leader>hp", gitsigns.preview_hunk)
                    map("n", "<leader>hi", gitsigns.preview_hunk_inline)

                    map("n", "<leader>hb", function()
                        gitsigns.blame_line({ full = true })
                    end)

                    map("n", "<leader>hd", gitsigns.diffthis)
                    map("n", "<leader>hD", function()
                        gitsigns.diffthis("~")
                    end)

                    map("n", "<leader>hq", gitsigns.setqflist)
                    map("n", "<leader>hQ", function()
                        gitsigns.setqflist("all")
                    end)

                    -- Changed from default tb
                    map("n", "<leader>ha", gitsigns.toggle_current_line_blame)
                    -- Changed from default tw
                    map("n", "<leader>hw", gitsigns.toggle_word_diff)

                    map({ "o", "x" }, "ih", gitsigns.select_hunk)
                end,
            })
        end,
    },
}
