-- FUTURE: Because I just use this for the indentation ruler, actually feasible to re-create

local function setup_ibl()
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

    local indent_char = "│"

    require("ibl").setup({
        indent = { char = indent_char },
        scope = { enabled = false, show_start = false, show_end = false },
        exclude = { filetypes = excluded_filetypes },
        whitespace = { highlight = { "Normal" } },
        debounce = 200,
    })
end

vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile" }, {
    group = vim.api.nvim_create_augroup("load-indent_highlight", { clear = true }),
    once = true,
    callback = function()
        require("mjm.pack").post_load("indent-blankline.nvim")
        setup_ibl()
    end,
})
