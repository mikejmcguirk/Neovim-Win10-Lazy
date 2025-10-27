local function load_lazydev()
    require("lazydev.config").setup({
        library = {
            "${3rd}/busted/library",
            "${3rd}/luassert/library",
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
        vim.api.nvim_del_augroup_by_name("setup-lazydev")
    end,
})

-- LOW: Why do semantic tokens not trigger properly after workspace updates?
-- LOW: I would like to not use this plugin, but always bringing in the whole RTP is slow
