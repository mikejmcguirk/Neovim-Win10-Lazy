local api = vim.api
return {
    "lewis6991/gitsigns.nvim",
    config = function()
        local gitsigns = require("gitsigns")
        gitsigns.setup({
            signs = {
                add = { text = "+" },
                change = { text = "~" },
            },
            on_attach = function(buf)
                local function set(mode, lhs, rhs, opts)
                    opts = opts or {}
                    opts.buffer = buf
                    vim.keymap.set(mode, lhs, rhs, opts)
                end

                local function diff_set(lhs, nav, opts, backup)
                    set("n", lhs, function()
                        local win = api.nvim_get_current_win()
                        if api.nvim_get_option_value("diff", { win = win }) then
                            api.nvim_cmd({ cmd = "normal", args = { backup }, bang = true }, {})
                        else
                            gitsigns.nav_hunk(nav, opts)
                        end
                    end)
                end

                diff_set("[c", "prev", { greedy = true }, "[c")
                diff_set("]c", "next", { greedy = true }, "]c")
                diff_set("[C", "first", { greedy = true }, "[c")
                diff_set("]C", "last", { greedy = true }, "]c")
                diff_set("[<C-c>", "prev", { greedy = true, target = "staged" }, "[c")
                diff_set("]<C-c>", "next", { greedy = true, target = "staged" }, "]c")
                diff_set("[<M-c>", "first", { greedy = true, target = "staged" }, "[c")
                diff_set("]<M-c>", "last", { greedy = true, target = "staged" }, "]c")

                -- NOTE: stage_hunk is also undo stage
                set("n", "<leader>hs", gitsigns.stage_hunk)
                set("n", "<leader>hr", gitsigns.reset_hunk)

                set("v", "<leader>hs", function()
                    gitsigns.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
                end)

                set("v", "<leader>hr", function()
                    gitsigns.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
                end)

                set("n", "<leader>hS", gitsigns.stage_buffer)
                set("n", "<leader>hi", gitsigns.preview_hunk_inline)
                set("n", "<leader>hd", gitsigns.diffthis)

                -- Changed from default tw
                set("n", "<leader>hw", gitsigns.toggle_word_diff)
                set({ "o", "x" }, "ic", gitsigns.select_hunk)
            end,
        })
    end,
}
