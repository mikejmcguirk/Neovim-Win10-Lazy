local jump2d = require("mini.jump2d")
jump2d.setup({
    allowed_lines = {
        blank = false,
        fold = false,
    },
    mappings = {
        start_jumping = nil,
    },
    view = {
        n_steps_ahead = 1,
    },
    silent = true,
})

Map("n", "<cr>", function()
    jump2d.start(jump2d.builtin_opts.word_start)
end)

vim.api.nvim_set_hl(0, "MiniJump2dSpot", { reverse = true })
vim.api.nvim_set_hl(0, "MiniJump2dSpotAhead", { reverse = true })
