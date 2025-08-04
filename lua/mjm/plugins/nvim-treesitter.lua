local configs = require("nvim-treesitter.configs")

configs.setup({
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
        "javascript",
        "json",
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
            lookahead = false, -- Don't jump to next text object
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

-- Defer execution until after Neovim automatically executes packadd. I have the vim.pack step
-- to do so early disabled
vim.api.nvim_create_autocmd("VimEnter", {
    group = vim.api.nvim_create_augroup("run-tsupdate", { clear = true }),
    pattern = "*",
    callback = function()
        vim.schedule_wrap(function()
            vim.cmd("TSUpdate")
        end)
    end,
})
