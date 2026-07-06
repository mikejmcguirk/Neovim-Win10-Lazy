local api = vim.api
local lsp = vim.lsp

local catharsis = require("catharsis")
require("catharsis._features")

if not catharsis.config.default_keymaps_set then
    return
end

local group_name = "catharsis.keymap_set"
local group = api.nvim_create_augroup(group_name, {})

---@param buf uinteger
---@param lhs string
---@param rhs string
---@param opts vim.api.keyset.keymap
local function safe_buf_map(buf, lhs, rhs, opts)
    if #vim.call("maparg", lhs, "n") == 0 then
        api.nvim_buf_set_keymap(buf, "n", lhs, rhs, opts)
    end
end

api.nvim_create_autocmd("LspAttach", {
    group = group,
    desc = "Create keymaps for LSP Catharsis",
    callback = function(ev)
        local client_id = ev.data.client_id
        local client = lsp.get_client_by_id(client_id)
        if not client then
            return
        end

        local buf = ev.buf
        safe_buf_map(buf, "[h", "", {
            noremap = true,
            desc = "Jump to previous document highlight",
            callback = function()
                require("catharsis._document_highlight").jump(vim.v.count1, true)
            end,
        })

        safe_buf_map(buf, "]h", "", {
            noremap = true,
            desc = "Jump to next document highlight",
            callback = function()
                require("catharsis._document_highlight").jump(vim.v.count1, false)
            end,
        })

        safe_buf_map(buf, "grn", "", {
            noremap = true,
            desc = "Rename a symbol with a default prompt",
            callback = function()
                require("catharsis").rename()
            end,
        })

        safe_buf_map(buf, "grN", "", {
            noremap = true,
            desc = "Rename a symbol without a default prompt",
            callback = function()
                require("catharsis").rename({ prompt_default = false })
            end,
        })
    end,
})
-- TODO: These should all have plugs, but want to try to generate them automatically.
