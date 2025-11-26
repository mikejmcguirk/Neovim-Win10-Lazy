local api = vim.api
local oil = Mjm_Defer_Require("oil")

local function close_oil()
    if api.nvim_get_option_value("modified", { buf = 0 }) then
        api.nvim_echo({ { "Oil buffer has unsaved changes" } }, false, {})
    else
        oil.close()
    end
end

return {
    "stevearc/oil.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    ---@module 'oil'
    ---@type oil.SetupOpts
    opts = {
        columns = { "size", "permissions" },
        float = { padding = 3 },
        keymaps = {
            ["`"] = { "actions.parent", mode = "n" }, --- Patternful with vinegar mapping
            ["~"] = { "actions.open_cwd", mode = "n" }, --- Vinegar style mapping
            ["-"] = { close_oil, mode = "n" },
            ["+"] = { close_oil, mode = "n" },
            ["<C-^>"] = { close_oil, mode = "n" }, -- Vinegar style mapping
            ["q"] = {
                function()
                    oil.discard_all_changes()
                    oil.close()
                end,
                mode = "n",
            },
            ["Q"] = {
                function()
                    oil.save({ confirm = nil }, function(err)
                        if err and err == "Canceled" then
                            return
                        elseif err then
                            api.nvim_echo({ { err } }, true, { err = true })
                        else
                            oil.close()
                        end
                    end)
                end,
                mode = "n",
            },
            ["<C-c>"] = false,
            ["_"] = false,
        },
        view_options = { show_hidden = true },
        watch_for_changes = true,
    },
    init = function()
        vim.keymap.set("n", "-", function()
            require("oil").open_float()
        end)

        vim.keymap.set("n", "+", function()
            require("oil").open_float(vim.uv.cwd())
        end)
    end,
}
