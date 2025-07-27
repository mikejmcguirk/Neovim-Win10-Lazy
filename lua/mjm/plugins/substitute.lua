return {
    "gbprod/substitute.nvim",
    config = function()
        local substitute = require("substitute")
        substitute.setup({
            on_substitute = nil,
            yank_substituted_text = false,
            preserve_cursor_position = false,
            modifiers = nil,
            highlight_substituted_text = {
                enabled = true,
                timer = (Highlight_Time * 0.75),
            },
            range = {
                prefix = "s",
                prompt_current_text = false,
                confirm = false,
                complete_word = false,
                subject = nil,
                range = nil,
                suffix = "",
                auto_apply = false,
                cursor_position = "end",
            },
            exchange = {
                motion = false,
                use_esc_to_cancel = true,
                preserve_cursor_position = false,
            },
        })

        vim.keymap.set("n", "s", substitute.operator, { noremap = true })
        vim.keymap.set("x", "s", substitute.visual, { noremap = true })
        vim.keymap.set("n", "S", substitute.eol, { noremap = true })

        vim.api.nvim_set_hl(0, "SubstituteSubstituted", { link = "IncSearch" })
    end,
}
