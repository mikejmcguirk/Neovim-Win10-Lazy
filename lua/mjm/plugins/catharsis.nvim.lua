return {
    -- dir = "~/Documents/nvim-plugin-dev/catharsis.nvim/",
    "mikejmcguirk/catharsis.nvim",
    lazy = false,
    -- enabled = false,
    init = function()
        local api = vim.api

        ---@type table<string, fun(client_id: integer, action: lsp.Command|lsp.CodeAction):boolean>
        local action_filters = {
            ---@param _ integer
            ---@param action lsp.Command|lsp.CodeAction
            python = function(_, action)
                if action.disabled then
                    return false
                end

                local title = action.title ---@type string|nil
                if title == nil then
                    return true
                end

                if string.find(title, "Ruff: Fix all auto-fixable problems", 1, true) ~= nil then
                    return false
                end

                if string.find(title, "Ruff: Organize imports", 1, true) ~= nil then
                    return false
                end

                return true
            end,
        }
        -- TODO: This should be a client specific config.

        vim.g.catharsis = {
            document_highlight = {
                on_jump = function(_, _, _, info)
                    api.nvim_cmd({ cmd = "norm", args = { "zv" }, bang = true })
                    if info.did_scroll then
                        api.nvim_cmd({ cmd = "norm", args = { "zzze" }, bang = true })
                    end
                end,
            },
        }

        api.nvim_create_autocmd("LspAttach", {
            group = api.nvim_create_augroup("mjm.catharsis", {}),
            callback = function(ev)
                local buf = ev.buf
                local func = action_filters[api.nvim_get_option_value("filetype", { buf = buf })]
                if func ~= nil then
                    -- TODO: Unsure why this is showing a type warning
                    require("catharsis").buf_config({ lampshade = { action_filter = func } }, buf)
                end
            end,
        })
    end,
}
