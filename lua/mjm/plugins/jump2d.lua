return {
    "nvim-mini/mini.jump2d",
    keys = {
        {
            "<cr>",
            function()
                local jump2d = require("mini.jump2d")
                jump2d.start(jump2d.builtin_opts.word_start)
            end,
            mode = "n",
        },
    },
    version = "*",
    opts = {
        allowed_lines = { blank = false, fold = false },
        mappings = { start_jumping = nil },
        view = { n_steps_ahead = 1 },
        silent = true,
    },
    init = function()
        vim.api.nvim_set_hl(0, "MiniJump2dSpot", { reverse = true })
        vim.api.nvim_set_hl(0, "MiniJump2dSpotAhead", { reverse = true })
    end,
}
