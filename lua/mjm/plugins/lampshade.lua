local api = vim.api
local lsp = vim.lsp

return {
    "mikejmcguirk/lampshade.nvim",
    -- dir = "~/Documents/nvim-plugin-dev/lampshade.nvim/",
    init = function()
        vim.g.lampshade_default_autocmds = false

        local lamp_group_root = "mjm-lampshade-"
        local init_group_name = lamp_group_root .. "init"
        local init_group = api.nvim_create_augroup(init_group_name, {})

        ---@type table<string, fun(client_id: integer, action: lsp.Command|lsp.CodeAction):boolean>
        local action_filters = {
            ---@param _ integer
            ---@param action lsp.Command|lsp.CodeAction
            lua = function(_, action)
                if action.disabled then
                    return false
                end

                local title = action.title ---@type string|nil
                if not title then
                    return true
                end

                local param_change = string.find(title, "Change to parameter", 1, true)
                if param_change then
                    return false
                else
                    return true
                end
            end,

            ---@param _ integer
            ---@param action lsp.Command|lsp.CodeAction
            python = function(_, action)
                if action.disabled then
                    return false
                end

                local title = action.title ---@type string|nil
                if not title then
                    return true
                end

                local fix_all_str = "Ruff: Fix all auto-fixable problems"
                local fix_all = string.find(title, fix_all_str, 1, true)
                if fix_all then
                    return false
                end

                local organize_str = "Ruff: Organize imports"
                local organize = string.find(title, organize_str, 1, true)
                if organize then
                    return false
                end

                return true
            end,
        }

        api.nvim_create_autocmd("LspAttach", {
            group = init_group,
            callback = function(ev)
                local client = lsp.get_client_by_id(ev.data.client_id)
                if not client then
                    return
                end

                if not client:supports_method("textDocument/codeAction") then
                    return
                end

                local buf = ev.buf
                local buf_str = tostring(buf)
                local buf_group_name = lamp_group_root .. buf_str
                local buf_group = api.nvim_create_augroup(buf_group_name, {})

                local update_events = {
                    "BufEnter",
                    "CmdlineLeave",
                    "CursorMoved",
                    "DiagnosticChanged",
                    "InsertLeave",
                    "TextChanged",
                }

                local ft = api.nvim_get_option_value("filetype", { buf = buf }) ---@type string
                local opts = {} ---@type lampshade.UpdateLamp.Opts
                opts.on_actions = action_filters[ft]

                local lamp = require("lampshade")
                lamp.update_lamp(buf, opts)

                api.nvim_create_autocmd(update_events, {
                    group = buf_group,
                    buffer = buf,
                    desc = "Show lamp",
                    callback = function(iev)
                        if iev.event == "DiagnosticChanged" then
                            local mode = api.nvim_get_mode().mode
                            local short_mode = string.sub(mode, 1)
                            local bad_mode = string.match(short_mode, "[csS\19irR]")
                            if bad_mode then
                                return
                            end
                        end

                        lamp.update_lamp(iev.buf, opts)
                    end,
                })

                local clear_events = { "BufLeave", "CmdlineEnter", "InsertEnter" }
                api.nvim_create_autocmd(clear_events, {
                    group = buf_group,
                    buffer = buf,
                    desc = "Clear lamp",
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
                    desc = "Detach lamp",
                    callback = function(iev)
                        lamp.clear_lamp(iev.buf)
                        api.nvim_del_augroup_by_id(buf_group)
                    end,
                })
            end,
        })
    end,
}
