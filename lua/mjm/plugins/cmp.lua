-- TODO: Should try blink.cmp at some point
local cmp_config = function()
    vim.opt.completeopt = { "menu", "menuone", "noselect" }

    local cmp = require("cmp")
    local cmp_select = { behavior = cmp.SelectBehavior.Select }

    local win_settings = {
        border = "single",
        winhighlight = "Normal:Normal,FloatBorder:FloatBorder,CursorLine:Visual,Search:None",
        scrollbar = true,
    }

    local formatting = {
        expandable_indicator = true,
        fields = { "abbr", "kind", "menu" },
        format = function(entry, vim_item)
            local display_symbols = {
                nvim_lsp_signature_help = "[Signature]",
                nvim_lsp = "[LSP]",
                treesitter = "[Treesitter]",
                async_path = "[Path]",
                spell = "[Spell]",
                vsnip = "[Vsnip]",
                vim_dadbod_completion = "[dadbod-cmp]",
                ["vim-dadbod-completion"] = "[dadbod]",
                buffer = "[Buffer]",
                sql = "[Sql]",
            }

            vim_item.menu = display_symbols[entry.source.name] or ""
            return vim_item
        end,
    }

    cmp.setup({
        mapping = {
            ["<C-d>"] = cmp.mapping(cmp.mapping.scroll_docs(4)),
            ["<C-u>"] = cmp.mapping(cmp.mapping.scroll_docs(-4)),

            ["<C-p>"] = cmp.mapping(cmp.mapping.select_prev_item(cmp_select), { "i" }),
            ["<C-n>"] = cmp.mapping(cmp.mapping.select_next_item(cmp_select), { "i" }),

            -- Similar to the "Copilot pause" I've found myself experiencing an autocomplete pause
            -- Autocompletes will still display but need to be manually typed
            -- ["<C-y>"] = cmp.mapping(cmp.mapping.confirm({select = true}), {"i"}),
            ["<C-y>"] = cmp.mapping(nil),
            ["<C-e>"] = cmp.mapping(cmp.mapping.abort()),

            ["<Tab>"] = cmp.mapping(nil),
            ["<S-Tab>"] = cmp.mapping(nil),
            ["<CR>"] = cmp.mapping(nil),
        },
        snippet = {
            expand = function(args)
                vim.fn["vsnip#anonymous"](args.body)
            end,
        },
        window = {
            completion = win_settings,
            documentation = win_settings,
        },
        sources = {
            { name = "nvim_lsp_signature_help" },
            {
                name = "lazydev",
                group_index = 0, -- Skip loading LuaLS completions
            },
            { name = "nvim_lsp" },
            {
                name = "buffer",
                option = {
                    get_bufnrs = function()
                        return vim.api.nvim_list_bufs()
                    end,
                },
            },
            { name = "treesitter" },
            { name = "async_path" },
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
        formatting = formatting,
    })

    cmp.setup.filetype({ "sql" }, {
        sources = {
            { name = "vim-dadbod-completion" },
            { name = "buffer" },
            { name = "sql" },
        },
        formatting = formatting,
    })
end

return {
    {
        "hrsh7th/nvim-cmp",
        -- The stop in typing on InsertEnter is awkward
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            cmp_config()
        end,
        dependencies = {
            "hrsh7th/vim-vsnip",

            "hrsh7th/cmp-vsnip",
            "rafamadriz/friendly-snippets",

            "hrsh7th/cmp-nvim-lsp",
            "hrsh7th/cmp-nvim-lsp-signature-help", -- Show current function signature

            "hrsh7th/cmp-buffer",
            "f3fora/cmp-spell", -- From Nvim's built-in spell check
            "FelipeLema/cmp-async-path",

            "ray-x/cmp-sql",
            "kristijanhusak/vim-dadbod-completion",
        },
    },
}
