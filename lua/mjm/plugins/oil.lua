local api = vim.api
local set = vim.keymap.set
local uv = vim.uv

local function close_oil()
    if api.nvim_get_option_value("modified", { buf = 0 }) then
        api.nvim_echo({ { "Oil buffer has unsaved changes" } }, false, {})
    else
        require("oil").close()
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
            -- Vinegar mapping.
            ["~"] = {
                function()
                    require("oil").open(uv.os_homedir())
                end,
            },
            ["`"] = { "actions.open_cwd", mode = "n" }, -- Vinegar style mapping.
            ["-"] = { "actions.parent", mode = "n" }, -- Vinegar mapping
            ["<C-^>"] = { close_oil, mode = "n" }, -- Vinegar mapping
            ["q"] = {
                function()
                    local oil = require("oil")
                    oil.discard_all_changes()
                    oil.close()
                end,
                mode = "n",
            },
            ["Q"] = {
                function()
                    require("oil").save({ confirm = nil }, function(err)
                        if err and err == "Canceled" then
                            return
                        elseif err then
                            api.nvim_echo({ { err } }, true, { err = true })
                        else
                            require("oil").close()
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
        set({ "x", "o" }, "-", "<nop>")
        set("n", "-", function()
            require("oil").open_float()
        end)
    end,
}

-- LOW: Do we still want to use floating buffer? It's not really a good pattern with Neovim, but
-- one significant benefit is that you get the sense of what context you are in. If you hit open,
-- or open split, you know where it's being done
-- Could maybe do the cmd line attached style layout here, so it feels less arbitrary
-- The philosophical issue is - A floating window should feel like it has an anchor point, and
-- right now it just arbitrarily floats there, which is bad
