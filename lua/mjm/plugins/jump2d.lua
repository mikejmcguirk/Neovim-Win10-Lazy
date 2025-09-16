local function load_jump2d()
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
end

vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile" }, {
    group = vim.api.nvim_create_augroup("load-jump2d", { clear = true }),
    once = true,
    callback = function()
        load_jump2d()
        vim.api.nvim_del_augroup_by_name("load-jump2d")
    end,
})
