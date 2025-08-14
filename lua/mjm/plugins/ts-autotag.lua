local function load_ts_autotag()
    require("nvim-ts-autotag").setup({
        opts = {
            enable_close = true,
            enable_rename = true,
            enable_close_on_slash = false,
        },
    })
end

vim.api.nvim_create_autocmd("InsertEnter", {
    group = vim.api.nvim_create_augroup("load-ts-autotag", { clear = true }),
    once = true,
    callback = function()
        require("mjm.pack").post_load("nvim-ts-autotag")
        load_ts_autotag()
    end,
})
