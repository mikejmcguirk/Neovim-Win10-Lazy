local api = vim.api
local group = "zen-tmux-status" ---@type string
local tmux_status = vim.api.nvim_create_augroup(group, {}) ---@type integer

---@param cmd_parts string[]
---@return nil
local function if_tmux(cmd_parts)
    if os.getenv("TMUX") == nil then return end
    vim.system(cmd_parts, { text = true, timeout = 1000 })
end

return {
    "folke/snacks.nvim",
    priority = 1000,
    ---@type snacks.Config
    opts = {
        bigfile = { enabled = false },
        dashboard = { enabled = false },
        explorer = { enabled = false },
        image = { enabled = true },
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
                if_tmux({ "tmux", "set", "status", "off" })
                vim.api.nvim_clear_autocmds({ group = group })
                -- Don't rely on the on_close callback to re-open the tmux statusline
                vim.api.nvim_create_autocmd({ "VimLeave" }, {
                    group = tmux_status,
                    callback = function()
                        if_tmux({ "tmux", "set", "status", "on" })
                    end,
                })
            end,
            on_close = function()
                if_tmux({ "tmux", "set", "status", "on" })
                vim.api.nvim_clear_autocmds({ group = group })
            end,
        },
    },
    init = function()
        vim.keymap.set("n", "<leader>e", function()
            local zen = require("snacks.zen")
            if not zen.win then
                local buf = vim.api.nvim_get_current_buf() ---@type integer
                local ft = api.nvim_get_option_value("filetype", { buf = buf }) ---@type string
                for _, bad_ft in pairs({ "NvimTree", "harpoon", "qf" }) do
                    if ft == bad_ft then
                        api.nvim_echo({ { "Zen disabled for filetype " .. ft } }, false, {})
                        return
                    end
                end
            end

            zen.zen({})
        end)
    end,
}
