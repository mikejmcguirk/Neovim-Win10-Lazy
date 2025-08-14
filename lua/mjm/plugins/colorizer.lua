local function setup_colorizer()
    require("colorizer").setup({
        -- disabled for filetypes that work with LSP document_color
        filetypes = {
            "!lua",
        },
        user_default_options = {
            names = false,
        },
    })
end

vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile" }, {
    group = vim.api.nvim_create_augroup("setup-colorizer", { clear = true }),
    once = true,
    callback = function()
        require("mjm.pack").post_load("nvim-colorizer.lua")
        setup_colorizer()
    end,
})
