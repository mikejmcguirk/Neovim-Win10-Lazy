local api = vim.api
local lsp = vim.lsp

vim.keymap.set("n", "<cr>", function()
    require("farsight.jump").jump({ all_wins = true })
end)

vim.keymap.set({ "x", "o" }, "<cr>", function()
    require("farsight.jump").jump({})
end)

vim.g.action_lamp_default_autocmds = false
require("action-lamp")

-- TODO: lamp_group_ns still isn't quite right
local lamp_group_ns = "action-lamp-" ---@type string
local init_group_name = lamp_group_ns .. "init" ---@type string
local init_group = api.nvim_create_augroup(init_group_name, {}) ---@type integer

api.nvim_create_autocmd("LspAttach", {
    group = init_group,
    callback = function(ev)
        local client = lsp.get_client_by_id(ev.data.client_id) ---@type vim.lsp.Client?
        if not client then
            return
        end

        if not client:supports_method("textDocument/codeAction") then
            return
        end

        -- Even though the autocmds are buffer scoped, assign them to a group so they are
        -- de-duplicated if multiple LSPs attach
        local buf = ev.buf ---@type integer
        local buf_str = tostring(buf) ---@type string
        local buf_group_name = lamp_group_ns .. buf_str ---@type string
        local buf_group = api.nvim_create_augroup(buf_group_name, {}) ---@type integer

        -- TODO: Consider removing the cmd line events from the base config. If the user
        -- does something that creates an enter error, they are caught in a loop because the
        -- lightbulb will refire every time it's closed

        ---@type string[]
        local update_events = {
            "BufEnter",
            "CmdlineLeave", -- Don't put in the default config
            "CursorMoved",
            "InsertLeave",
            "TextChanged",
        }

        local opts = {} ---@type actionlamp.UpdateLamp.Opts
        opts.triggerKind = lsp.protocol.CodeActionTriggerKind.Invoked

        local ft = api.nvim_get_option_value("filetype", { buf = buf }) ---@type string
        if ft == "lua" then
            update_events[#update_events + 1] = "DiagnosticChanged"
            opts.filter = function(_, action)
                local title = action.title ---@type string|nil
                if not title then
                    return true
                end

                ---@type integer|nil
                local param_change = string.find(title, "Change to parameter", 1, true)
                if param_change then
                    return false
                else
                    return true
                end
            end
        end

        local lamp = require("action-lamp.lamp")
        lamp.update_lamp(buf, opts)

        api.nvim_create_autocmd(update_events, {
            group = buf_group,
            buffer = buf,
            desc = "Show action lamp",
            callback = function(iev)
                lamp.update_lamp(iev.buf, opts)
            end,
        })

        -- TODO: Don't put CmdlineEnter in the default clear events
        local clear_events = { "BufLeave", "CmdlineEnter", "InsertEnter" } ---@type string[]
        api.nvim_create_autocmd(clear_events, {
            group = buf_group,
            buffer = buf,
            desc = "Clear action lamp",
            callback = function(iev)
                lamp.clear_lamp(iev.buf)
                if iev.event == "CmdlineEnter" then
                    api.nvim_cmd({ cmd = "redraw" }, {})
                end
            end,
        })

        api.nvim_create_autocmd("LspDetach", {
            group = buf_group,
            buffer = buf,
            desc = "Detach action lamp",
            callback = function(iev)
                lamp.clear_lamp(iev.buf)
                api.nvim_del_augroup_by_id(buf_group)
            end,
        })
    end,
})
