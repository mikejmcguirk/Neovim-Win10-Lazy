local api = vim.api
local set = vim.keymap.set

return {
    "lewis6991/gitsigns.nvim",
    config = function()
        api.nvim_set_hl(0, "GitSignsCurrentLineBlame", { link = "LspInlayHint" })

        local gitsigns = require("gitsigns")
        gitsigns.setup({
            signs = { add = { text = "+" }, change = { text = "~" } },
            on_attach = function(buf)
                ---@param lhs string
                ---@param nav string
                ---@param nav_opts Gitsigns.NavOpts
                ---@param backup string
                ---@param opts vim.keymap.set.Opts
                local function diff_set(lhs, nav, nav_opts, backup, opts)
                    set("n", lhs, function()
                        local win = api.nvim_get_current_win()
                        if not api.nvim_get_option_value("diff", { win = win }) then
                            gitsigns.nav_hunk(nav, nav_opts)
                            return
                        end

                        api.nvim_cmd({
                            cmd = "normal",
                            args = { backup },
                            bang = true,
                        }, {})
                    end, opts)
                end
                -- MAYBE: Allow this to map in visual mode. I don't know what the diff mode cmds
                -- would do though.

                local buf_opt = { buf = buf }

                local greedy = { greedy = true }
                local greedy_staged = { greedy = true, target = "staged" }
                diff_set("[c", "prev", greedy, "[c", buf_opt)
                diff_set("]c", "next", greedy, "]c", buf_opt)
                diff_set("[C", "first", greedy, "[c", buf_opt)
                diff_set("]C", "last", greedy, "]c", buf_opt)
                diff_set("[<C-c>", "prev", greedy_staged, "[c", buf_opt)
                diff_set("]<C-c>", "next", greedy_staged, "]c", buf_opt)
                diff_set("[<M-c>", "first", greedy_staged, "[c", buf_opt)
                diff_set("]<M-c>", "last", greedy_staged, "]c", buf_opt)

                -- NOTE: stage_hunk is also undo stage
                set("n", "<leader>hs", gitsigns.stage_hunk, buf_opt)
                set("n", "<leader>hr", gitsigns.reset_hunk, buf_opt)
                set("n", "<leader>hS", gitsigns.stage_buffer, buf_opt)
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
                end, buf_opt)

                set("v", "<leader>hs", function()
                    gitsigns.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
                end, buf_opt)

                set("v", "<leader>hr", function()
                    gitsigns.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
                end, buf_opt)

                -- NON: The ns_clear for this is hidden behind an autocmd. I think you could
                -- hack your way into clearing the ns and autocmd on pressing <leader>hi again,
                -- but would be contrived.
                set("n", "<leader>hi", gitsigns.preview_hunk_inline, buf_opt)
                set("n", "<leader>hb", gitsigns.toggle_current_line_blame, buf_opt)
                -- Changed from default tw
                set("n", "<leader>hw", gitsigns.toggle_word_diff, buf_opt)
                set("n", "<leader>hd", function()
                    local PREFIX_END = 11

                    for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
                        local bufnr = api.nvim_win_get_buf(win)
                        local bufname = api.nvim_buf_get_name(bufnr)
                        local prefix = string.sub(bufname, 1, PREFIX_END)
                        if prefix == "gitsigns://" then
                            api.nvim_win_close(win, true)
                            return
                        end
                    end

                    gitsigns.diffthis()
                end, buf_opt)
                -- MAYBE: Get the origin buf of the diff_win and move the cursor there if it's in
                -- the diff_win. This would require using gitsigns's logic to transform the
                -- bufname, which starts getting contrived. And I'm not sure it's part of the API.
                -- FUTURE: If I run into any edge cases, address here.

                set({ "o", "x" }, "ic", gitsigns.select_hunk, buf_opt)
            end,
        })
    end,
}
