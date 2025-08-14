local function setup_flash()
    require("flash.config").setup({
        modes = {
            char = {
                enabled = false,
            },
        },
        jump = {
            pos = "end", -- Match how / and ? work
        },
        highlight = {
            backdrop = false,
            groups = {
                current = "QuickScopeSecondary",
                label = "QuickScopePrimary",
                match = "QuickScopeSecondary",
            },
        },
    })

    vim.keymap.set({ "n", "x" }, "gs", function()
        require("flash").jump({
            search = { forward = true, wrap = false, multi_window = false },
        })
    end)

    vim.keymap.set({ "n", "x" }, "gS", function()
        require("flash").jump({
            search = { forward = false, wrap = false, multi_window = false },
        })
    end)
end

vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile" }, {
    group = vim.api.nvim_create_augroup("load-flash", { clear = true }),
    once = true,
    callback = function()
        require("mjm.pack").post_load("flash.nvim")
        setup_flash()
    end,
})
