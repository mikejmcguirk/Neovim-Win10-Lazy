return {
    {
        "windwp/nvim-autopairs",
        event = "InsertEnter",
        config = function()
            local autopairs = require("nvim-autopairs")
            autopairs.setup({
                check_ts = true,
            })

            -- TODO: Can we handle Rust autoclosing this way?
            -- Autoclosing angle-brackets.
            -- autopairs.add_rule(require("nvim-autopairs.rule")("<", ">", {
            --     -- Avoid conflicts with nvim-ts-autotag.
            --     "-html",
            --     "-javascriptreact",
            --     "-typescriptreact",
            -- })
            --     :with_pair(require("nvim-autopairs.conds").before_regex("%a+:?:?$", 3))
            --     :with_move(function(opts)
            --         return opts.char == ">"
            --     end))

            local cmp_autopairs = require("nvim-autopairs.completion.cmp")
            local cmp = require("cmp")
            cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
        end,
    },
}
