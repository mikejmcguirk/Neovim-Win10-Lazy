return {
    {
        "numToStr/Comment.nvim",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            require("Comment").setup()
        end,
    },
    {
        "kylechui/nvim-surround",
        version = "*", -- Use for stability; omit to use `main` branch for the latest features
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            require("nvim-surround").setup({})
        end,
    },
    {
        "windwp/nvim-autopairs",
        event = "InsertEnter",
        config = function()
            require("nvim-autopairs").setup({
                check_ts = true,
                ts_config = {
                    lua = { "string" }, -- it will not add pair on that treesitter node
                    javascript = { "template_string" },
                    java = false, -- don't check treesitter on java
                },
            })

            local status, cmp = pcall(require, "cmp")

            if not status then
                return
            end

            local cmp_autopairs = require("nvim-autopairs.completion.cmp")
            cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
        end,
    },
    {
        "Wansmer/treesj",
        dependencies = { "nvim-treesitter/nvim-treesitter" },
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            local treesj = require("treesj")

            treesj.setup({
                use_default_keymaps = false,
                max_join_length = 99,
            })

            vim.keymap.set("n", "<leader>j", function()
                treesj.toggle({ split = { recursive = true } })
            end, Opts)
        end,
    },
    {
        "triglav/vim-visual-increment",
        event = { "BufReadPre", "BufNewFile" },
        init = function()
            vim.opt.nrformats = "alpha,octal,hex"
        end,
    },
}
