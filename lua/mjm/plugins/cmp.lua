local cmp_config = function()
    local cmp = require("cmp")

    local cmp_select = { behavior = cmp.SelectBehavior.Select }
    local win_highlight = "Normal:Normal,FloatBorder:FloatBorder,CursorLine:Visual,Search:None"
    vim.opt.completeopt = { "menu", "menuone", "noselect" }

    Lsp_Capabilities = vim.tbl_deep_extend(
        "force",
        Lsp_Capabilities,
        require("cmp_nvim_lsp").default_capabilities()
    )

    cmp.setup({
        enabled = function()
            local context = require("cmp.config.context")

            if vim.api.nvim_get_mode().mode == "c" then
                return true
            elseif vim.api.nvim_buf_get_option(0, "buftype") == "prompt" then
                return false
            else
                return not context.in_treesitter_capture("comment")
                    and not context.in_syntax_group("Comment")
            end
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
            },
            documentation = {
                border = "single",
                winhighlight = win_highlight,
            },
        },
        mapping = cmp.mapping.preset.insert({
            ["<C-d>"] = cmp.mapping.scroll_docs(4),
            ["<C-u>"] = cmp.mapping.scroll_docs(-4),

            ["<C-e>"] = cmp.mapping.abort(),
            ["<C-c>"] = function()
                cmp.mapping.abort()
                vim.cmd("stopinsert")
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
            { name = "nvim_lsp_signature_help" },
            { name = "nvim_lsp" },
            { name = "vsnip" },
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
        },
        formatting = {
            fields = { "abbr", "kind", "menu" },
            format = function(entry, vim_item)
                vim_item.menu = ({
                    buffer = "[Buffer]",
                    treesitter = "[Treesitter]",
                    nvim_lsp = "[LSP]",
                    vsnip = "[Vsnip]",
                    async_path = "[Path]",
                    spell = "[Spell]",
                })[entry.source.name]

                vim_item.menu = (vim_item.menu or "")
                return vim_item
            end,
        },
    })

    local cmp_autopairs = require("nvim-autopairs.completion.cmp")
    cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
end

return {
    {
        "hrsh7th/nvim-cmp",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            cmp_config()
        end,
        dependencies = {
            "hrsh7th/vim-vsnip", -- Snippets engine

            "rafamadriz/friendly-snippets", -- Snippets

            "hrsh7th/cmp-vsnip", -- From vsnip
            "hrsh7th/cmp-nvim-lsp", -- From LSPs
            "hrsh7th/cmp-buffer", -- From open buffers
            "hrsh7th/cmp-nvim-lsp-signature-help", -- Show current function signature
            "f3fora/cmp-spell", -- From Nvim's built-in spell check
            "FelipeLema/cmp-async-path", -- From filesystem
        },
    },
}