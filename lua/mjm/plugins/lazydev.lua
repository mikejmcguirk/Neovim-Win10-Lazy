local function load_lazydev()
    require("lazydev.config").setup({
        library = {
            -- Load luvit types when the `vim.uv` word is found
            { path = "${3rd}/luv/library", words = { "vim%.uv" } },
        },
    })
end

vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("setup-lazydev", { clear = true }),
    pattern = "lua",
    once = true,
    callback = function()
        load_lazydev()
    end,
})
