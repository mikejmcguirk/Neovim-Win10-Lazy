local function setup_autopairs()
    local npairs = require("nvim-autopairs")
    local rule = require("nvim-autopairs.rule")
    local cond = require("nvim-autopairs.conds")
    local ts_conds = require("nvim-autopairs.ts-conds")

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

    -- Auto add commas after lua table entries
    npairs.add_rules({
        rule("{", "},", "lua"):with_pair(ts_conds.is_ts_node({ "table_constructor" })),
        rule("'", "',", "lua"):with_pair(ts_conds.is_ts_node({ "table_constructor" })),
        rule('"', '",', "lua"):with_pair(ts_conds.is_ts_node({ "table_constructor" })),
    })

    local cmp_autopairs = require("nvim-autopairs.completion.cmp")
    local cmp = require("cmp")
    cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
end

vim.api.nvim_create_autocmd("InsertEnter", {
    group = vim.api.nvim_create_augroup("load-textmanip-insert", { clear = true }),
    once = true,
    callback = function()
        setup_autopairs()
    end,
})
