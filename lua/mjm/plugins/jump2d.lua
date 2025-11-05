local jump_2d_map = "<cr>"
return {
    "nvim-mini/mini.jump2d",
    -- Function args don't take properly if map is defined here
    keys = { { jump_2d_map, nil, mode = "n" } },
    version = "*",
    config = function()
        require("mini.jump2d").setup({
            allowed_lines = { blank = false, fold = false },
            mappings = { start_jumping = nil },
            view = { n_steps_ahead = 1 },
            silent = true,

            vim.keymap.set("n", jump_2d_map, function()
                local jump2d = require("mini.jump2d")
                jump2d.start(jump2d.builtin_opts.word_start)
            end),
        })

        vim.api.nvim_set_hl(0, "MiniJump2dSpot", { reverse = true })
        vim.api.nvim_set_hl(0, "MiniJump2dSpotAhead", { reverse = true })

        vim.keymap.set("n", "<cr>", function()
            local jump2d = require("mini.jump2d")
            jump2d.start(jump2d.builtin_opts.word_start)
        end)
    end,
}
