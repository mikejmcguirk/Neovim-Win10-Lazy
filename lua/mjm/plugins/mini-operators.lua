local function load_mini_operators()
    require("mini.operators").setup({
        evaluate = {
            prefix = "g=",
            func = nil,
        },
        -- FUTURE: Unsure how to map something like this to ()
        -- exchange = {
        --     prefix = "cx",
        --     reindent_linewise = true,
        -- },
        multiply = {
            prefix = "gm",
        },
        replace = {
            prefix = "s",
            reindent_linewise = true,
        },
        sort = {
            prefix = "gg",
        },
    })
end

vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile" }, {
    group = vim.api.nvim_create_augroup("load-mini-operators", { clear = true }),
    once = true,
    callback = function()
        load_mini_operators()
        vim.api.nvim_del_augroup_by_name("load-mini-operators")
    end,
})
