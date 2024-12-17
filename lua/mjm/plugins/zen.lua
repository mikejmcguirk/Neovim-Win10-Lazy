local tmux_safety = vim.api.nvim_create_augroup("tmux_safety", { clear = true })

-- Anything tmux related is handled manually because, by default, when zen-mode closes, it also
-- unhides all tmux panes
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
            vim.api.nvim_clear_autocmds({ group = "tmux_safety" })

            vim.api.nvim_create_autocmd({ "VimLeave" }, {
                group = tmux_safety,
                once = true,
                pattern = "*",
                callback = function()
                    pcall(function()
                        vim.fn.system([[tmux set status on]])
                    end)
                end,
            })

            vim.api.nvim_create_autocmd("WinClosed", {
                group = tmux_safety,
                once = true,
                pattern = "*",
                callback = function(event)
                    local closed_win = tonumber(event.match)
                    if closed_win == require("zen-mode.view").win then
                        pcall(function()
                            vim.fn.system([[tmux set status on]])
                        end)
                    end
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
