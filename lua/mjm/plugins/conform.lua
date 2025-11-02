local api = vim.api

local expr_group = "conform-formatexpr" ---@type string
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
} ---@type table<string, conform.FiletypeFormatter>

local fts = vim.tbl_keys(ft_config) ---@type string[]

local function setup_conform()
    local conform = require("conform")
    conform.setup({
        formatters_by_ft = ft_config,
    })

    vim.api.nvim_create_autocmd("BufWritePre", {
        group = vim.api.nvim_create_augroup("conformer", { clear = true }),
        callback = function(ev)
            local ft = vim.api.nvim_get_option_value("filetype", { buf = ev.buf }) ---@type string
            if not vim.tbl_contains(fts, ft) then return end
            conform.format({
                bufnr = ev.buf,
                lsp_fallback = false,
                async = false,
                timeout_ms = 1000,
            })
        end,
    })

    vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup(expr_group, { clear = true }),
        pattern = fts,
        callback = function(ev)
            local expr = "v:lua.require'conform'.formatexpr()" ---@type string
            vim.api.nvim_set_option_value("formatexpr", expr, { buf = ev.buf })
        end,
    })
end

local load_conform = api.nvim_create_augroup("load-conform", {})
vim.api.nvim_create_autocmd("FileType", {
    group = load_conform,
    pattern = fts,
    callback = function()
        setup_conform()
        vim.api.nvim_exec_autocmds("FileType", { group = expr_group })
        vim.api.nvim_del_augroup_by_id(load_conform)
    end,
})

-- LOW: Investigate dprint as a prettier alternative
