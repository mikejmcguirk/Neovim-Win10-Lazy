local function load_ts_autotag()
    require("nvim-ts-autotag").setup({
        opts = {
            enable_close = true,
            enable_rename = true,
            enable_close_on_slash = false,
        },
    })
end

local fts = { "html", "xml" }
vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("load-ts-autotag", { clear = true }),
    callback = function(ev)
        if not vim.tbl_contains(fts, ev.match) then
            return
        end

        load_ts_autotag()

        vim.api.nvim_del_augroup_by_name("load-ts-autotag")
    end,
})
