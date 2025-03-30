return {
    "gbprod/substitute.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
        require("substitute").setup({
            on_substitute = nil,
            yank_substituted_text = false,
            preserve_cursor_position = false,
            modifiers = nil,
            highlight_substituted_text = {
                enabled = true,
                timer = 150,
            },
        })

        local sub = require("substitute")
        vim.api.nvim_set_hl(0, "SubstituteSubstituted", { link = "IncSearch" })

        -- vim.keymap.set("n", "s", function()
        --     sub.operator({ modifiers = { "trim" } })
        -- end)
        -- vim.keymap.set("n", "S", sub.eol)
    end,
}
