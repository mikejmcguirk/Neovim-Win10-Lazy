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
            query = { "format-queries" },
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
            local ft = vim.api.nvim_get_option_value("filetype", { buf = ev.buf })
            if not vim.tbl_contains(valid_filetypes, ft) then
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

    vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("conform-formatexpr", { clear = true }),
        pattern = "*",
        callback = function(ev)
            if vim.tbl_contains(valid_filetypes, ev.match) then
                local expr = "v:lua.require'conform'.formatexpr()"
                vim.api.nvim_set_option_value("formatexpr", expr, { buf = ev.buf })
            end
        end,
    })
end

vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile" }, {
    group = vim.api.nvim_create_augroup("load-conform", { clear = true }),
    once = true,
    callback = function()
        setup_conform()
    end,
})
