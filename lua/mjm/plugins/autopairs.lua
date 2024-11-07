return {
    {
        -- TODO: Can we make this detect <> in Rust somehow?
        "windwp/nvim-autopairs",
        event = "InsertEnter",
        config = function()
            local autopairs = require("nvim-autopairs")
            autopairs.setup({
                check_ts = true,
                ts_config = {
                    lua = { "string" }, -- it will not add pair on that treesitter node
                    javascript = { "template_string" },
                    java = false, -- don't check treesitter on java
                },
                map_bs = false, -- To keep my <backspace> mapping intact
            })

            local cmp = require("cmp")
            local cmp_autopairs = require("nvim-autopairs.completion.cmp")
            cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
        end,
    },
}
