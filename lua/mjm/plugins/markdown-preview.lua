local api = vim.api
return {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    ft = { "markdown" },
    build = ":call mkdp#util#install()",
    -- build = function()
    --     -- vim.fn["mkdp#util#install"]()
    --     api.nvim_exec2("call mkdp#util#install", {})
    -- end,
    init = function()
        api.nvim_set_var("mkdp_auto_close", 1)
        api.nvim_set_var("mkdp_browser", "brave-browser-stable")
        api.nvim_set_var("mkdp_theme", "dark")

        api.nvim_create_autocmd("FileType", {
            group = api.nvim_create_augroup("mjm-markdown-preview", {}),
            pattern = "markdown",
            callback = function(ev)
                vim.keymap.set(
                    "n",
                    "<localleader>mm",
                    "<cmd>MarkdownPreviewToggle<cr>",
                    { buffer = ev.buf }
                )

                vim.keymap.set(
                    "n",
                    "<localleader>mp",
                    "<cmd>MarkdownPreview<cr>",
                    { buffer = ev.buf }
                )

                vim.keymap.set(
                    "n",
                    "<localleader>ms",
                    "<cmd>MarkdownPreviewStop<cr>",
                    { buffer = ev.buf }
                )
            end,
        })
    end,
}
