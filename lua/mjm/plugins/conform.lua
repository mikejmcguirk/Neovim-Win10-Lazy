---@type table<string, string[]>
local formatters_by_ft = {
    css = { "prettier" },
    go = { "gofumpt" },
    html = { "prettier" },
    json = { "prettier" },
    lua = { "stylua" },
    python = { "ruff_fix", "ruff_format" },
    rust = { "rustfmt" },
    query = { "format-queries" },
    sh = { "shfmt" },
    toml = { "taplo" },
    typst = { "typstyle" },
}

return {
    "stevearc/conform.nvim",
    opts = { formatters_by_ft = formatters_by_ft },
    init = function()
        local api = vim.api
        local set = vim.keymap.set

        local fts = {} ---@type string[]
        for ft, _ in pairs(formatters_by_ft) do
            fts[#fts + 1] = ft
        end

        local group_prefix = "mjm-conform-"
        local meta_group_str = group_prefix .. "meta"
        local group = api.nvim_create_augroup(meta_group_str, {})
        api.nvim_create_autocmd("FileType", {
            group = group,
            pattern = fts,
            callback = function(ev)
                local buf = ev.buf
                local conform = require("conform")
                local expr = "v:lua.require'conform'.formatexpr()"
                local function do_conform()
                    conform.format({
                        bufnr = buf,
                        lsp_fallback = false,
                        async = false,
                        timeout_ms = 1000,
                    })
                end

                set("n", mjm.v.fmt_lhs, do_conform, { buf = buf })
                api.nvim_set_option_value("formatexpr", expr, { buf = buf })
                local buf_group_str = group_prefix .. tostring(buf)
                api.nvim_create_autocmd("BufWritePre", {
                    group = api.nvim_create_augroup(buf_group_str, {}),
                    buffer = buf,
                    callback = do_conform,
                })
            end,
        })

        local info_toggle = "<leader>ci"
        set("n", info_toggle, "<cmd>ConformInfo<cr>")
        api.nvim_create_autocmd("FileType", {
            group = group,
            pattern = "conform-info",
            callback = function(ev)
                set("n", info_toggle, "<cmd>close<cr>", { buf = ev.buf })
            end,
        })
    end,
}

-- MAYBE: https://github.com/neovim/neovim/discussions/35602
-- Probably not, but interesting to have around
