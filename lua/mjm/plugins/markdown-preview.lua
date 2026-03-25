local api = vim.api
return {
    "iamcco/markdown-preview.nvim",
    ft = { "markdown" },
    build = function()
        vim.fn["mkdp#util#install"]()
    end,
    init = function()
        api.nvim_set_var("mkdp_auto_close", 1)
        api.nvim_set_var("mkdp_browser", "brave-browser-stable")
        api.nvim_set_var("mkdp_theme", "dark")

        api.nvim_create_autocmd("FileType", {
            group = api.nvim_create_augroup("mjm-markdown-preview", {}),
            pattern = "markdown",
            callback = function(ev)
                local toggle = "<cmd>MarkdownPreviewToggle<cr>"
                local preview = "<cmd>MarkdownPreview<cr>"
                local stop = "<cmd>MarkdownPreviewStop<cr>"
                vim.keymap.set("n", "<localleader>mm", toggle, { buf = ev.buf })
                vim.keymap.set("n", "<localleader>mp", preview, { buf = ev.buf })
                vim.keymap.set("n", "<localleader>ms", stop, { buf = ev.buf })
            end,
        })
    end,
}
