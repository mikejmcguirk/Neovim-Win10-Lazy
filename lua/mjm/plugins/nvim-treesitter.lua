local ts = require("nvim-treesitter")
ts.setup({
    install_dir = vim.fn.stdpath("data") .. "/site",
})

local languages = {
    -- Mandatory
    "c",
    "lua",
    "vim",
    "vimdoc",
    "query",
    "markdown_inline",
    "markdown",
    -- Optional
    "javascript",
    "html",
    "css",
    "rust",
    "sql",
    "python",
    "json",
    "typescript",
    "bash",
    "go",
}
ts.install(languages)

vim.api.nvim_create_autocmd({ "FileType" }, {
    group = vim.api.nvim_create_augroup("ts-start", { clear = true }),
    pattern = "*",
    callback = function(ev)
        local ft = vim.api.nvim_get_option_value("filetype", { buf = ev.buf })
        if vim.tbl_contains(languages, ft) then
            vim.treesitter.start()
        end

        vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end,
})
