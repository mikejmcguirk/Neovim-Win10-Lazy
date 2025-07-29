local function setup_conform()
    require("conform").setup({
        formatters_by_ft = {
            css = { "prettier" },
            go = { "gofumpt" },
            html = { "prettier" },
            json = { "prettier" },
            lua = { "stylua" },
            python = { "ruff_format" },
            rust = { "rustfmt" },
            sh = { "shfmt" },
            toml = { "taplo" },
        },
    })

    local valid_filetypes = {
        "css",
        "go",
        "html",
        "json",
        "lua",
        "python",
        "rust",
        "sh",
        "toml",
    }

    vim.api.nvim_create_autocmd("BufWritePre", {
        group = vim.api.nvim_create_augroup("conformer", { clear = true }),
        pattern = "*",
        callback = function(ev)
            if not vim.tbl_contains(valid_filetypes, vim.bo[ev.buf].filetype) then
                return
            end

            require("conform").format({
                bufnr = ev.buf,
                lsp_fallback = false,
                async = false,
                timeout_ms = 1000,
            })
        end,
    })

    vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
end

vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile" }, {
    group = vim.api.nvim_create_augroup("load-conform", { clear = true }),
    once = true,
    callback = function()
        setup_conform()
    end,
})
