local api = vim.api

local group_name = "zen-tmux-safety" ---@type string
local tmux_safety = vim.api.nvim_create_augroup(group_name, {}) ---@type integer

require("snacks").setup({
    bigfile = { enabled = false },
    dashboard = { enabled = false },
    explorer = { enabled = false },
    image = { enabled = false },
    indent = { animate = { enabled = false }, scope = { enabled = false } },
    input = { enabled = false },
    notifier = { enabled = false },
    quickfile = { enabled = false },
    scope = { enabled = false },
    scroll = { enabled = false },
    statuscolumn = { enabled = false },
    words = { enabled = false },
    zen = {
        toggles = { dim = false, git_signs = false, mini_diff_signs = false },
        win = { width = 106, style = "zen" },
        on_open = function()
            pcall(function()
                vim.fn.system([[tmux set status off]])
            end)

            vim.api.nvim_clear_autocmds({ group = group_name })
            -- Don't rely on the on_close callback to re-open the tmux statusline
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
        end,
        on_close = function()
            pcall(function()
                vim.fn.system([[tmux set status on]])
            end)

            vim.api.nvim_clear_autocmds({ group = group_name })
        end,
    },
})

local bad_filetypes = { "NvimTree", "harpoon", "qf" }
vim.keymap.set("n", "<leader>e", function()
    local zen = require("snacks.zen")
    if not zen.win then
        local buf = vim.api.nvim_get_current_buf() ---@type integer
        local ft = api.nvim_get_option_value("filetype", { buf = buf }) ---@type string
        for _, bft in pairs(bad_filetypes) do
            if ft == bft then
                api.nvim_echo({ { "Zen disabled for filetype " .. ft } }, false, {})
                return
            end
        end
    end

    zen.zen({})
end)
