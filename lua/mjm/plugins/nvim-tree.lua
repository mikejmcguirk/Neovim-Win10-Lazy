return {
    "nvim-tree/nvim-tree.lua",
    version = "*",
    lazy = true,
    cmd = {
        "NvimTreeToggle",
        "NvimTreeFindFile",
        "NvimTreeOpen",
        "NvimTreeClose",
    },
    dependencies = {
        "nvim-tree/nvim-web-devicons",
    },
    init = function()
        vim.keymap.set("n", "<leader>nt", "<cmd>NvimTreeToggle<cr>")
        vim.keymap.set("n", "<leader>nr", "<cmd>NvimTreeRefresh<cr>")
        vim.keymap.set("n", "<leader>nf", "<cmd>NvimTreeFocus<cr>")
        vim.keymap.set("n", "<leader>ni", "<cmd>NvimTreeFindFile<cr>")
    end,
    config = function()
        require("nvim-tree").setup({
            disable_netrw = true,
            hijack_netrw = true,
            sort_by = "case_sensitive",
            view = {
                width = 36,
                relativenumber = true,
            },
            filters = {
                git_ignored = false,
            },
            diagnostics = {
                enable = true,
            },
            notify = {
                threshold = vim.log.levels.WARN,
                absolute_path = true,
            },
            on_attach = function(bufnr)
                local api = require("nvim-tree.api")

                api.config.mappings.default_on_attach(bufnr)
                vim.keymap.del("n", "<2-LeftMouse>", { buffer = bufnr })
                vim.keymap.del("n", "<2-RightMouse>", { buffer = bufnr })
                vim.keymap.set("n", "y", "<nop>", { buffer = bufnr })
            end,
        })
    end,
}
