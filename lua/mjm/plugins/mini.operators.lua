local set = vim.keymap.set

return {
    "nvim-mini/mini.operators",
    version = "*",
    config = function()
        local mini_ops = require("mini.operators")
        mini_ops.setup({
            evaluate = { prefix = "g=", func = nil },
            -- MAYBE: Unsure how to map something like this to ()
            exchange = { prefix = "", reindent_linewise = true },
            multiply = { prefix = "gm" },
            replace = { prefix = "gs", reindent_linewise = true },
            sort = { prefix = "" },
        })

        -- Goal: Map forward and reverse sort functions.
        -- Problem: mini.operators.sort() does not have a sort function param. Instead, it checks
        -- buffer local config then its internal config.
        -- Non-solution: Only manually map reverse sort, using vim.schedule to reset vim.b.
        -- Creates complexity surface area.
        -- Solution: Manually map sort.

        local odesc = "Sort"
        ---@type vim.keymap.set.Opts
        local expr_opts = { expr = true, replace_keycodes = false, desc = odesc }

        ---@param mode "char"|"line"|"block"|"visual"|nil
        ---@param opts table
        ---@return string?
        local function do_sort(mode, opts)
            vim.b.minioperators_config = opts
            return mini_ops.sort(mode)
        end

        set("n", "gt", function()
            return do_sort(nil, { sort = { func = nil } })
        end, expr_opts)

        set("n", "gtt", "^gtg_", { remap = true, desc = odesc .. " line" })
        set("x", "gt", function()
            do_sort("visual", { sort = { func = nil } })
        end, { desc = odesc .. " selection" })

        ---@param content table
        ---@return string[]
        local rev_sort_func = function(content)
            return mini_ops.default_sort_func(content, {
                compare_fun = function(a, b)
                    return b < a
                end,
            })
        end

        local rev_operator_desc = odesc .. " (reverse)"
        expr_opts.desc = rev_operator_desc

        set("n", "gT", function()
            return do_sort(nil, { sort = { func = rev_sort_func } })
        end, expr_opts)

        set("n", "gTT", "^gTg_", { remap = true, desc = rev_operator_desc .. " line" })
        set("x", "gT", function()
            do_sort("visual", { sort = { func = rev_sort_func } })
        end, { desc = odesc .. " selection" })
    end,
    -- PR: It should not be necessary to do this. Challenging to change though because the
    -- operator entry point calls itself recursively. Using operatorfunc.
}
