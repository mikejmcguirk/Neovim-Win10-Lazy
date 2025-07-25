-- Anything tmux related is handled manually because, by default, when zen-mode closes, it also
-- unhides all tmux panes
local tmux_safety = vim.api.nvim_create_augroup("tmux_safety", { clear = true })

return {
    "folke/zen-mode.nvim",
    opts = {
        window = {
            width = 106, -- 99 text columns + gutter
        },
        plugins = {
            options = {
                showcmd = true,
            },
        },
        on_open = function()
            -- Just pcall anything tmux related so we don't have issues on non-tmux setups
            pcall(function()
                vim.fn.system([[tmux set status off]])
            end)

            -- In case clear on toggle off doesn't run for some reason
            vim.api.nvim_clear_autocmds({ group = "tmux_safety" })
            -- Needed because the on_close callback does not fire, at least not in the expected
            -- manner, when Nvim is closed from within a Zen window
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

            -- Avoid issue where you toggle NvimTree closed underneath the Zen window
            vim.keymap.set("n", "<leader>nt", "<cmd>NvimTreeOpen<cr>")
            -- Will close Zen but then focus on the Zen-creating buffer. Pointless to have
            vim.keymap.set("n", "<leader>nf", "<nop>")
        end,
        on_close = function()
            vim.keymap.set("n", "<leader>nn", "<cmd>NvimTreeToggle<cr>")
            vim.keymap.set("n", "<leader>nf", "<cmd>NvimTreeFocus<cr>")

            pcall(function()
                vim.fn.system([[tmux set status on]])
            end)

            vim.api.nvim_clear_autocmds({ group = "tmux_safety" })
        end,
    },
    -- Done using an init because config overwrites the opts table
    init = function()
        vim.keymap.set("n", "<leader>e", function()
            local view = require("zen-mode.view")
            if view.is_open() then
                view.close()
                return
            end

            local bad_filetypes = {
                "NvimTree",
                "harpoon",
                "qf",
            }

            for _, ft in pairs(bad_filetypes) do
                if vim.bo.filetype == ft then
                    vim.notify("Zen open map disabled for filetype " .. ft)
                    return
                end
            end

            view.open()
        end)
    end,
}
