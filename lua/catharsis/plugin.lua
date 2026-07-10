local api = vim.api
local lsp = vim.lsp

local catharsis = require("catharsis")
require("catharsis._features")

-- stylua: ignore
local maps = {
{ { "n" }, "<Plug>(catharsis-doc-hl-jump-rev)", "[h", "",
    "Jump to previous document highlight", function()
        require("catharsis").document_highlight.jump_rev()
    end, },
{ { "n" }, "<Plug>(catharsis-doc-hl-jump-fwd)", "]h", "",
    "Jump to next document highlight", function()
        require("catharsis").document_highlight.jump_fwd()
    end, },
{ { "n" }, "<Plug>(catharsis-doc-hl-jump-first)", "[H", "",
    "Jump to first document highlight", function()
        require("catharsis").document_highlight.jump_first()
    end, },
{ { "n" }, "<Plug>(catharsis-doc-hl-jump-last)", "]H", "",
    "Jump to last document highlight", function()
        require("catharsis").document_highlight.jump_last()
    end, },
{ { "n" }, "<Plug>(catharsis-inc-rename-prompt)", "grn", "",
    "Rename a symbol with a default prompt", function()
        require("catharsis").rename()
    end, },
{ { "n" }, "<Plug>(catharsis-inc-rename-empty)", "grN", "",
    "Rename a symbol without a default prompt", function()
        require("catharsis").rename({ prompt_default = false })
    end, },
}

for _, map in ipairs(maps) do
    for _, mode in ipairs(map[1]) do
        api.nvim_set_keymap(mode, map[2], map[4], {
            noremap = true,
            desc = map[5],
            callback = map[6],
        })
    end
end

if not catharsis.config.default_keymaps_set then
    return
end

local group = api.nvim_create_augroup("catharsis.keymap_set", {})

api.nvim_create_autocmd("LspAttach", {
    group = group,
    desc = "Create keymaps for LSP Catharsis",
    callback = function(ev)
        if not lsp.get_client_by_id(ev.data.client_id) then
            return
        end

        local buf = ev.buf
        for _, map in ipairs(maps) do
            for _, mode in ipairs(map[1]) do
                -- MID: Use `mapcheck()` or `hasmapto()`
                if #vim.call("maparg", map[3]) == 0 then
                    api.nvim_buf_set_keymap(buf, mode, map[3], map[2], {
                        noremap = true,
                        desc = map[5],
                    })
                end
            end
        end
    end,
})
