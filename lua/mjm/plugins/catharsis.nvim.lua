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
            lua = function(_, action)
                if action.disabled then
                    return false
                end

                local title = action.title ---@type string|nil
                if not title then
                    return true
                end

                if string.find(title, "use cast to remove nil", 1, true) ~= nil then
                    return false
                end

                return string.find(title, "Change to parameter", 1, true) == nil
            end,

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
