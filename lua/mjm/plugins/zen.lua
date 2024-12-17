return {
    "folke/zen-mode.nvim",
    opts = {
        window = {
            width = 106,
        },
        plugins = {
            options = {
                showcmd = true,
            },
            tmux = { enabled = true },
        },
        on_open = function()
            vim.api.nvim_create_autocmd("VimLeave", {
                group = vim.api.nvim_create_augroup("tmux_safety", { clear = true }),
                pattern = "*",
                callback = function()
                    require("zen-mode.plugins").tmux({ status = "on" }, false)
                end,
            })
        end,
    },
    -- Done using an init because config overwrites the opts table
    init = function()
        vim.keymap.set("n", "<leader>e", function()
            vim.cmd("ZenMode")
        end)
    end,
}
