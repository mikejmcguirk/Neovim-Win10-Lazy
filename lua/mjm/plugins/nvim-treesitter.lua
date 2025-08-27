vim.cmd.packadd({ vim.fn.escape("nvim-treesitter", " "), bang = true, magic = { file = false } })
local text_objects = "nvim-treesitter-textobjects"
vim.cmd.packadd({ vim.fn.escape(text_objects, " "), bang = true, magic = { file = false } })

require("nvim-treesitter.configs").setup({
    modules = {},
    ignore_install = {},
    auto_install = false,
    ensure_installed = {
        -- Mandatory
        "c",
        "lua",
        "vim",
        "vimdoc",
        "query",
        "markdown_inline",
        "markdown",
        -- Optional
        "c_sharp",
        "bash",
        "css",
        "diff",
        "javascript",
        "json",
        "gitattributes",
        "gitcommit",
        "gitignore",
        "git_rebase",
        "go",
        "html",
        "perl",
        "python",
        "rust",
        "sql",
        "tmux",
        "typescript",
    },
    sync_install = false,
    highlight = { enable = true, additional_vim_regex_highlighting = false },
    indent = { enable = true },
    textobjects = {
        select = {
            enable = true,
            lookahead = true,
            keymaps = {
                ["a,"] = "@parameter.outer",
                ["i,"] = "@parameter.inner",
            },
        },
        move = {
            enable = true,
            set_jumps = true,
            goto_previous_start = {
                ["[,"] = "@parameter.inner",
            },
            goto_next_start = {
                ["],"] = "@parameter.inner",
            },
        },
    },
})

vim.api.nvim_create_autocmd("VimEnter", {
    group = vim.api.nvim_create_augroup("run-tsupdate", { clear = true }),
    once = true,
    pattern = "*",
    callback = function()
        vim.schedule_wrap(function()
            vim.cmd("TSUpdate")
        end)
    end,
})
