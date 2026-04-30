local api = vim.api

return {
    "lewis6991/gitsigns.nvim",
    config = function()
        api.nvim_set_hl(0, "GitSignsCurrentLineBlame", { link = "LspInlayHint" })

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
                set("n", "<leader>hR", function()
                    local ntu = require("nvim-tools.ui")
                    local ok, input = ntu.get_input("Reset buffer? [y/n]: ")
                    if not ok then
                        local err = input or "Unknown error getting input"
                        ntu.echo_err(false, err, "ErrorMsg")
                        return
                    elseif input == "" then
                        return
                    end

                    local first_byte = string.byte(input, 1)
                    if first_byte == 89 or first_byte == 121 then
                        gitsigns.reset_buffer()
                    end
                end)

                set("v", "<leader>hs", function()
                    gitsigns.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
                end)

                set("v", "<leader>hr", function()
                    gitsigns.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
                end)

                set("n", "<leader>hS", gitsigns.stage_buffer)
                set("n", "<leader>hi", gitsigns.preview_hunk_inline)
                set("n", "<leader>hd", gitsigns.diffthis)

                set("n", "<leader>hb", gitsigns.toggle_current_line_blame)

                -- Changed from default tw
                set("n", "<leader>hw", gitsigns.toggle_word_diff)
                set({ "o", "x" }, "ic", gitsigns.select_hunk)
            end,
        })
    end,
}
