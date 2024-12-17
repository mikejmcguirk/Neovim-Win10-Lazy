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
        },
        on_open = function()
            vim.api.nvim_create_autocmd({ "QuitPre", "VimLeave" }, {
                group = vim.api.nvim_create_augroup("tmux_safety", { clear = true }),
                pattern = "*",
                callback = function()
                    pcall(function()
                        vim.fn.system([[tmux set status on]])
                    end)
                end,
            })
        end,
    },
    -- Done using an init because config overwrites the opts table
    init = function()
        vim.keymap.set("n", "<leader>e", function()
            local view = require("zen-mode.view")

            if not view.is_open() then
                view.open()
                pcall(function()
                    vim.fn.system([[tmux set status off]])
                end)
            else
                view.close()
                pcall(function()
                    vim.fn.system([[tmux set status on]])
                end)
            end
        end)
    end,
}
