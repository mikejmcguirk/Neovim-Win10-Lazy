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

        local odesc_s = "Sort"
        ---@type vim.keymap.set.Opts
        local expr_opts_s = { expr = true, replace_keycodes = false, desc = odesc_s }

        ---@param mode "char"|"line"|"block"|"visual"|nil
        ---@param opts table
        ---@return string?
        local function do_sort(mode, opts)
            vim.b.minioperators_config = opts
            return mini_ops.sort(mode)
        end

        set("n", "gt", function()
            return do_sort(nil, { sort = { func = nil } })
        end, expr_opts_s)

        local desc_line = " line"
        set("n", "gtt", "^gtg_", { remap = true, desc = odesc_s .. desc_line })
        set("x", "gt", function()
            do_sort("visual", { sort = { func = nil } })
        end, { desc = odesc_s .. " selection" })

        ---@param content table
        ---@return string[]
        local rev_sort_func = function(content)
            return mini_ops.default_sort_func(content, {
                compare_fun = function(a, b)
                    return b < a
                end,
            })
        end

        local odesc_s_rev = odesc_s .. " (reverse)"
        expr_opts_s.desc = odesc_s_rev

        set("n", "gT", function()
            return do_sort(nil, { sort = { func = rev_sort_func } })
        end, expr_opts_s)

        set("n", "gTT", "^gTg_", { remap = true, desc = odesc_s_rev .. desc_line })
        set("x", "gT", function()
            do_sort("visual", { sort = { func = rev_sort_func } })
        end, { desc = odesc_s_rev .. " selection" })

        -----------------------------------------------
        -- Map alt+replace to use the plus register. --
        -----------------------------------------------

        local odesc_r = "Replace"
        local desc_eol = " (end of line)"
        set("n", "gS", "gsg_", { desc = odesc_r .. desc_eol, remap = true })

        local replace_plus_maps = { "<M-g><M-s>", "g<M-s>" }
        local desc_plus = " (plus register)"
        local odesc_r_plus = odesc_r .. desc_plus
        local opts_r = {}
        for _, rmap in ipairs(replace_plus_maps) do
            opts_r.remap = true
            opts_r.desc = odesc_r_plus
            set("n", rmap, [[\"+gs]], opts_r)

            opts_r.desc = odesc_r_plus .. desc_line
            set("n", rmap .. "s", [[\"+gs_]], opts_r)

            opts_r.desc = odesc_r_plus .. " selection"
            opts_r.remap = false
            -- Could not get this to work as a remap for whatever reason.
            local vis_cmd = [["+<cmd>lua MiniOperators.replace('visual')<CR>]]
            set("x", rmap, vis_cmd, opts_r)
        end

        local replace_plus_maps_eol = { "<M-g><M-S>", "g<M-S>" }
        opts_r.desc = odesc_r_plus .. desc_eol
        opts_r.remap = true
        for _, rmap in ipairs(replace_plus_maps_eol) do
            set("n", rmap, [[\"+gsg_]], opts_r)
        end
    end,
}
