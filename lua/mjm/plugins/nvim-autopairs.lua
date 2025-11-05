return {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = function()
        local npairs = require("nvim-autopairs")
        local rule = require("nvim-autopairs.rule")
        local cond = require("nvim-autopairs.conds")

        npairs.setup({
            check_ts = true,
        })

        -- Autoclosing angle-brackets for generics
        -- NOTE: Just spot checking, this seems to adequately handle the main cases this
        -- comes up in Rust
        npairs.add_rule(rule("<", ">", {
            -- Avoid conflicts with nvim-ts-autotag.
            "-html",
            "-javascriptreact",
            "-typescriptreact",
        }):with_pair(cond.before_regex("%a+:?:?$", 3)):with_move(function(opts)
            return opts.char == ">"
        end))
    end,
}
