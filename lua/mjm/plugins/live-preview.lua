local fts = { "css", "html", "markdown" }
return {
    "brianhuster/live-preview.nvim",
    ft = fts,
    init = function()
        local api = vim.api
        local group = api.nvim_create_augroup("mjm.live-preview")
        api.nvim_create_autocmd("FileType", {
            group = group,
            pattern = fts,
            callback = function(ev)
                local buf = ev.buf
                vim.keymap.set("n", "<localleader>ls", "<cmd>LivePreview start<cr>", { buf = buf })
                vim.keymap.set("n", "<localleader>lc", "<cmd>LivePreview close<cr>", { buf = buf })
            end,
        })
    end,
}
