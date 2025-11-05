local api = vim.api

local function load_lightbulb()
    local lightbulb = require("nvim-lightbulb")
    lightbulb.setup({
        autocmd = { enabled = false },
        code_lenses = false,
        float = { enabled = false },
        hide_in_unfocused_buffer = false, -- Handled by autocmd below
        number = { enabled = false },
        line = { enabled = false },
        sign = { enabled = false },
        status_text = { enabled = false },
        virtual_text = { enabled = true, text = "󰌶", lens_text = "🔎" },
    })

    local attach_lightbulb = api.nvim_create_augroup("attach-lightbulb", {})
    api.nvim_create_autocmd("LspAttach", {
        group = attach_lightbulb,
        callback = function(ev)
            local group_name = "lightbulb-" .. tostring(ev.buf)
            local lb_buf_group = api.nvim_create_augroup(group_name, { clear = true })

            -- The default autocmds change the updatetime option and operate across all buffers
            api.nvim_create_autocmd({ "CursorMoved", "TextChanged", "InsertLeave" }, {
                group = lb_buf_group,
                buffer = ev.buf,
                desc = "lua require('nvim-lightbulb').update_lightbulb()",
                callback = lightbulb.update_lightbulb,
            })

            -- Set up autocmd for clear_lightbulb if configured
            api.nvim_create_autocmd({ "InsertEnter", "WinLeave" }, {
                group = lb_buf_group,
                desc = "lua require('nvim-lightbulb').clear_lightbulb()",
                callback = function()
                    lightbulb.clear_lightbulb(ev.buf)
                end,
            })

            api.nvim_create_autocmd("LspDetach", {
                group = lb_buf_group,
                buffer = ev.buf,
                desc = "Detach code action lightbulb",
                callback = function()
                    pcall(api.nvim_del_augroup_by_name, group_name)
                end,
            })
        end,
    })

    api.nvim_exec_autocmds("LspAttach", { group = attach_lightbulb })
end

return {
    "kosayoda/nvim-lightbulb",
    -- TODO: Does this properly hold back loading? Are we better off just using the default?
    init = function()
        local load_group = api.nvim_create_augroup("load-lightbulb", {})
        api.nvim_create_autocmd("LspAttach", {
            group = load_group,
            once = true,
            callback = function()
                load_lightbulb()
            end,
        })
    end,
}

-- LOW: Create custom lightbulb
-- - https://github.com/MariaSolOs/dotfiles/blob/main/.config/nvim/lua/lightbulb.lua
