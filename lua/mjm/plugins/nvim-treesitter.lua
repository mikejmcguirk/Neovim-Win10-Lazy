vim.cmd.packadd({ vim.fn.escape("nvim-treesitter", " "), bang = true, magic = { file = false } })

vim.cmd.packadd({
    vim.fn.escape("nvim-treesitter-textobjects", " "),
    bang = true,
    magic = { file = false },
})

vim.cmd.packadd({
    vim.fn.escape("nvim-treesitter-context", " "),
    bang = true,
    magic = { file = false },
})

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

local border = vim.api.nvim_get_hl(0, { name = "FloatBorder" })
vim.api.nvim_set_hl(0, "TreesitterContextBottom", { underline = true, sp = border.fg })
-- TreesitterContextLineNumberBottom links to TreesitterContextBottom by default

-- Defer until the plugin is fully sourced
vim.api.nvim_create_autocmd("VimEnter", {
    group = vim.api.nvim_create_augroup("run-tsupdate", { clear = true }),
    pattern = "*",
    callback = function()
        vim.schedule_wrap(function()
            vim.cmd("TSUpdate")
        end)
    end,
})
