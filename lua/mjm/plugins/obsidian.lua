local workspaces = {
    {
        name = "main",
        path = "~/obsidian/main",
    },
}

local note_events = {}
for _, workspace in ipairs(workspaces) do
    local expanded_path = vim.fn.expand(workspace.path) .. "/*.md"
    table.insert(note_events, "BufReadPre " .. expanded_path)
    table.insert(note_events, "BufNewFile " .. expanded_path)
end

return {
    "epwalsh/obsidian.nvim",
    version = "*",
    -- Must be lazy loaded, or else it will try and fail to load in invalid directories
    -- Just setting lazy load = true does not work, so custom logic is built out here to
    -- only load the plugin when entering an Obsidian buffer, since the plugin's functionality is
    -- all tied to being in a relevant buffer anyway
    lazy = true,
    event = note_events,
    dependencies = {
        "nvim-lua/plenary.nvim",
    },
    config = function()
        require("obsidian").setup({
            workspaces = workspaces,
            completion = {
                nvim_cmp = true,
                min_chars = 1,
            },
            mappings = {},
            ui = {
                enable = false,
            },
            disable_frontmatter = true, -- The aliasing creates inconsistent behavior with the GUI
            -- Use the note title as the filename
            -- I would like to validate that the filename is valid on Windows, but I can't because
            -- cmp uses this when autocompleting [[]] bracket names
            note_id_func = function(title)
                if title ~= nil then
                    return title
                else
                    return nil -- This makes the LSP complain, but I want the error
                end
            end,
        })

        -- TODO: Create a map with [o and ]o that advances to the next/previous file in a folder
        vim.keymap.set("n", "<cr>", "<cmd>ObsidianFollowLink<cr>")
        vim.keymap.set("n", "<leader>ta", "<cmd>ObsidianBacklinks<cr>")
        vim.keymap.set("n", "<leader>tn", "<cmd>ObsidianLinks<cr>")
        vim.keymap.set("n", "<leader>sr", "<cmd>ObsidianRename<cr>")
    end,
}
