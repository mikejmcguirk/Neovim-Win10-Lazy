return {
    "folke/lazydev.nvim",
    ft = "lua",
    opts = {
        library = {
            "${3rd}/busted/library",
            "${3rd}/luassert/library",
            -- Load luvit types when the `vim.uv` word is found
            { path = "${3rd}/luv/library", words = { "vim%.uv" } },
        },
    },
    init = function()
        vim.lsp.config("lua_ls", {
            root_dir = function(bufnr, on_dir)
                on_dir(require("lazydev").find_workspace(bufnr))
            end,
        })
    end,
}

-- LOW: Why do semantic tokens not trigger properly after workspace updates?
-- LOW: It would be better to just handle this in house. The blocker is the piece-wise workspace
-- loading. Loading/using the whole runtime is glacially slow
