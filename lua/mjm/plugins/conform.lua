local api = vim.api

local ft_cfg = {
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
    -- TODO: Configure to remove trailing blanks
    typst = { "typstyle" },
} ---@type table<string, conform.FiletypeFormatter>

local fts = vim.tbl_keys(ft_cfg)
return {
    "stevearc/conform.nvim",
    opts = { formatters_by_ft = ft_cfg },
    init = function()
        local do_conform = function(buf)
            local ft = api.nvim_get_option_value("filetype", { buf = buf })
            if not vim.tbl_contains(fts, ft) then
                local chunk = { "Filetype " .. ft .. " not configured for Conform" }
                api.nvim_echo({ chunk }, false, {})
                return
            end

            require("conform").format({
                bufnr = buf,
                lsp_fallback = false,
                async = false,
                timeout_ms = 1000,
            })
        end

        -- PR: Add a filetype to this window buf so I can map co to quit
        vim.keymap.set("n", "<leader>ci", "<cmd>ConformInfo<cr>")
        vim.keymap.set("n", "<leader>co", function()
            do_conform(0)
        end)

        api.nvim_create_autocmd("FileType", {
            group = api.nvim_create_augroup("conformer", {}),
            pattern = fts,
            callback = function(ev)
                local expr = "v:lua.require'conform'.formatexpr()" ---@type string
                api.nvim_set_option_value("formatexpr", expr, { buf = ev.buf })
                api.nvim_create_autocmd("BufWritePre", {
                    group = api.nvim_create_augroup("conform-" .. tostring(ev.buf), {}),
                    buffer = ev.buf,
                    callback = function()
                        do_conform(ev.buf)
                    end,
                })
            end,
        })
    end,
}

-- MAYBE: https://github.com/neovim/neovim/discussions/35602
-- Probably not, but interesting to have around
