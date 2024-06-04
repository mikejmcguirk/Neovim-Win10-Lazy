local cmp_config = function()
    local cmp = require("cmp")

    local cmp_select = { behavior = cmp.SelectBehavior.Select }
    local win_highlight = "Normal:Normal,FloatBorder:FloatBorder,CursorLine:Visual,Search:None"
    vim.opt.completeopt = { "menu", "menuone", "noselect" }

    cmp.setup({
        enabled = function()
            local context = require("cmp.config.context")

            local in_ts_capture_comment = context.in_treesitter_capture("comment")
            local in_comment_syntax = context.in_syntax_group("Comment")
            local is_comment = in_ts_capture_comment or in_comment_syntax
            local is_prompt = vim.api.nvim_buf_get_option(0, "buftype") == "prompt"

            if is_prompt or is_comment then
                return false
            end

            return true
        end,
        snippet = {
            expand = function(args)
                vim.fn["vsnip#anonymous"](args.body)
            end,
        },
        window = {
            completion = {
                border = "single",
                winhighlight = win_highlight,
                scrollbar = true,
            },
            documentation = {
                border = "single",
                winhighlight = win_highlight,
                scrollbar = true,
            },
        },
        mapping = cmp.mapping.preset.insert({
            ["<C-d>"] = cmp.mapping.scroll_docs(4),
            ["<C-u>"] = cmp.mapping.scroll_docs(-4),

            ["<C-e>"] = cmp.mapping.abort(),
            ["<C-c>"] = function()
                cmp.mapping.abort()
                vim.api.nvim_exec2("stopinsert", {})
            end,

            ["<C-p>"] = cmp.mapping.select_prev_item(cmp_select),
            ["<C-n>"] = cmp.mapping.select_next_item(cmp_select),
            ["<C-y>"] = cmp.mapping.confirm({ select = true }),
            -- ["<C-<space>>"] = cmp.mapping.complete(),

            ["<Tab>"] = nil,
            ["<S-Tab>"] = nil,
            ["<CR>"] = nil,
        }),
        sources = {
            {
                name = "lazydev",
                group_index = 0, -- Skip loading LuaLS completions
            },
            { name = "nvim_lsp_signature_help" },
            { name = "nvim_lsp" },
            {
                name = "buffer",
                option = {
                    get_bufnrs = function()
                        return vim.api.nvim_list_bufs()
                    end,
                },
            },
            { name = "async_path" },
            { name = "treesitter" },
            {
                name = "spell",
                option = {
                    keep_all_entries = false,
                    enable_in_context = function()
                        return true
                    end,
                },
            },
            { name = "vsnip" },
        },
        formatting = {
            fields = { "abbr", "kind", "menu" },
            format = function(entry, vim_item)
                vim_item.menu = ({
                    buffer = "[Buffer]",
                    treesitter = "[Treesitter]",
                    nvim_lsp = "[LSP]",
                    nvim_lsp_signature_help = "[Signature]",
                    vsnip = "[Vsnip]",
                    async_path = "[Path]",
                    spell = "[Spell]",
                })[entry.source.name]

                vim_item.menu = (vim_item.menu or "")
                return vim_item
            end,
        },
    })
end

return {
    {
        "hrsh7th/nvim-cmp",
        event = { "InsertEnter" },
        config = function()
            cmp_config()
        end,
        dependencies = {
            "hrsh7th/vim-vsnip", -- Snippets engine

            "rafamadriz/friendly-snippets", -- Snippets

            "hrsh7th/cmp-vsnip", -- From vsnip
            "hrsh7th/cmp-nvim-lsp",
            "hrsh7th/cmp-buffer",
            "hrsh7th/cmp-nvim-lsp-signature-help", -- Show current function signature
            "f3fora/cmp-spell", -- From Nvim's built-in spell check
            "FelipeLema/cmp-async-path",
        },
    },
}
