return {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    opts = {},
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
        {
            "echasnovski/mini.indentscope",
            version = "*",
        },
    },
    config = function()
        local indent_char = "│"
        local excluded_filetypes = {
            "help",
            "neo-tree",
            "Trouble",
            "trouble",
            "lazy",
            "mason",
            "toggleterm",
            "harpoon",
            "NvimTree",
        }

        local has_indentscope, indentscope = pcall(require, "mini.indentscope")
        local show_ibl_scope = not has_indentscope

        require("ibl").setup({
            indent = { char = indent_char },
            scope = {
                enabled = show_ibl_scope,
                show_start = false,
                show_end = false,
            },
            exclude = {
                filetypes = excluded_filetypes,
            },
            whitespace = { highlight = { "Normal" } },
            debounce = 200,
        })

        if not has_indentscope then
            return
        end

        indentscope.setup({
            symbol = indent_char,
            options = {
                try_as_border = false,
                indent_at_cursor = false,
            },
            draw = {
                delay = 0,
                animation = indentscope.gen_animation.none(),
            },
        })

        vim.api.nvim_set_hl(0, "MiniIndentscopeSymbolOff", {
            bg = vim.api.nvim_get_hl(0, { name = "MiniIndentscopeSymbol" }).bg,
            fg = vim.api.nvim_get_hl(0, { name = "MiniIndentscopeSymbol" }).fg,
        })

        vim.api.nvim_set_hl(0, "MiniIndentscopeSymbol", {
            bg = vim.api.nvim_get_hl(0, { name = "IblScope" }).bg,
            fg = vim.api.nvim_get_hl(0, { name = "IblScope" }).fg,
        })

        vim.api.nvim_create_autocmd("FileType", {
            group = vim.api.nvim_create_augroup("indentscope_group", { clear = true }),
            pattern = excluded_filetypes,
            callback = function()
                vim.b.miniindentscope_disable = true
            end,
        })
    end,
}
