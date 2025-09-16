--- LOW: dprint looks like an interesting alternative
--- @type table<string, conform.FiletypeFormatter>
local ft_config = {
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
}

local function setup_conform()
    require("conform").setup({
        formatters_by_ft = ft_config,
    })

    vim.api.nvim_create_autocmd("BufWritePre", {
        group = vim.api.nvim_create_augroup("conformer", { clear = true }),
        pattern = "*",
        callback = function(ev)
            local ft = vim.api.nvim_get_option_value("filetype", { buf = ev.buf })
            if not vim.tbl_contains(vim.tbl_keys(ft_config), ft) then
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
        pattern = vim.tbl_keys(ft_config),
        callback = function(ev)
            local expr = "v:lua.require'conform'.formatexpr()"
            vim.api.nvim_set_option_value("formatexpr", expr, { buf = ev.buf })
        end,
    })
end

vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("load-conform", { clear = true }),
    callback = function(ev)
        if not vim.tbl_contains(vim.tbl_keys(ft_config), ev.match) then
            return
        end

        setup_conform()
        vim.api.nvim_exec_autocmds("FileType", { group = "conform-formatexpr" })

        vim.api.nvim_del_augroup_by_name("load-conform")
    end,
})
