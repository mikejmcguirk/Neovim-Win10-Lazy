local function setup_colorizer()
    require("colorizer").setup({
        user_default_options = {
            names = false,
        },
    })
end

vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile" }, {
    group = vim.api.nvim_create_augroup("setup-colorizer", { clear = true }),
    once = true,
    callback = function()
        setup_colorizer()
    end,
})
