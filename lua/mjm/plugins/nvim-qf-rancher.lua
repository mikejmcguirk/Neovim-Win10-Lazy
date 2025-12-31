local api = vim.api
local set = vim.keymap.set

return {
    "mikejmcguirk/nvim-qf-rancher",
    -- dir = "~/Documents/nvim-plugin-dev/nvim-qf-rancher/",
    init = function()
        -- vim.api.nvim_set_var("qfr_create_loclist_autocmds", false) -- For debugging

        set("n", "[<M-q>", "<Plug>(qfr-qf-older)")
        set("n", "]<M-q>", "<Plug>(qfr-qf-newer)")
        set("n", "[<M-l>", "<Plug>(qfr-ll-older)")
        set("n", "]<M-l>", "<Plug>(qfr-ll-newer)")

        api.nvim_create_autocmd("FileType", {
            group = api.nvim_create_augroup("mjm-rancher", {}),
            pattern = "qf",
            callback = function()
                local previewer = require("qf-rancher.preview")
                set("n", "p", function()
                    previewer.toggle_preview_win({ border = "bold", debounce = 50 })
                end, { buffer = 0 })
            end,
        })
    end,
}
