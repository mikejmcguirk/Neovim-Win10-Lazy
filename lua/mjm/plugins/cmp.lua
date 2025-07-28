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
    snippet = {
        expand = function(args)
            vim.fn["vsnip#anonymous"](args.body)
        end,
    },
    window = {
        completion = win_settings,
        documentation = win_settings,
    },
    mapping = {
        ["<C-d>"] = cmp.mapping(cmp.mapping.scroll_docs(3)),
        ["<C-u>"] = cmp.mapping(cmp.mapping.scroll_docs(-5)),

        ["<cr>"] = cmp.mapping(nil),
        ["<C-cr>"] = cmp.mapping(cmp.mapping.confirm({ select = true }), { "i" }),
        ["<C-y>"] = cmp.mapping(nil),
        ["<C-p>"] = cmp.mapping(cmp.mapping.select_prev_item(cmp_select), { "i" }),
        ["<C-n>"] = cmp.mapping(cmp.mapping.select_next_item(cmp_select), { "i" }),

        ["<C-e>"] = cmp.mapping(nil),

        ["<Tab>"] = cmp.mapping(nil),
        ["<S-Tab>"] = cmp.mapping(nil),
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
