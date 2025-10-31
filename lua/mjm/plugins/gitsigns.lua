local api = vim.api
local gitsigns = require("gitsigns")

gitsigns.setup({
    signs = {
        add = { text = "+" },
        change = { text = "~" },
    },
    on_attach = function(buf)
        local function map(mode, lhs, rhs, opts)
            opts = opts or {}
            opts.buffer = buf
            vim.keymap.set(mode, lhs, rhs, opts)
        end

        local function diff_map(lhs, nav, opts, backup)
            map("n", lhs, function()
                local win = api.nvim_get_current_win()
                if api.nvim_get_option_value("diff", { win = win }) then
                    api.nvim_cmd({ cmd = "normal", args = { backup }, bang = true }, {})
                else
                    gitsigns.nav_hunk(nav, opts)
                end
            end)
        end

        diff_map("[c", "prev", { greedy = true }, "[c")
        diff_map("]c", "next", { greedy = true }, "]c")
        diff_map("[C", "first", { greedy = true }, "[c")
        diff_map("]C", "last", { greedy = true }, "]c")
        diff_map("[<C-c>", "prev", { greedy = true, target = "staged" }, "[c")
        diff_map("]<C-c>", "next", { greedy = true, target = "staged" }, "]c")
        diff_map("[<M-c>", "first", { greedy = true, target = "staged" }, "[c")
        diff_map("]<M-c>", "last", { greedy = true, target = "staged" }, "]c")

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
        map("n", "<leader>hi", gitsigns.preview_hunk_inline)
        map("n", "<leader>hd", gitsigns.diffthis)

        -- Changed from default tw
        map("n", "<leader>hw", gitsigns.toggle_word_diff)
        map({ "o", "x" }, "ic", gitsigns.select_hunk)
    end,
})
