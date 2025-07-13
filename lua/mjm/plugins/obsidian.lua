-- Only load if we enter a .md file in a defined Obsidian workspace
local note_events = {}
local workspaces = {
    {
        name = "main",
        path = "~/Documents/obsidian/main",
    },
} ---@type table

for _, workspace in pairs(workspaces) do
    local expanded_path = vim.fn.expand(workspace.path) .. "/*.md" ---@type string
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
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
        local img_folder = "assets/imgs"

        local obsidian = require("obsidian")
        obsidian.setup({
            workspaces = workspaces,
            completion = {
                nvim_cmp = true,
                min_chars = 1,
            },
            mappings = {},
            ui = {
                enable = false,
                checkboxes = {
                    [" "] = { order = 1, char = "󰄱", hl_group = "ObsidianTodo" },
                    -- ["~"] = { order = 2, char = "󰰱", hl_group = "ObsidianTilde" },
                    ["x"] = { order = 5, char = "", hl_group = "ObsidianDone" },
                },
            },
            disable_frontmatter = true, -- The aliasing creates inconsistent behavior with the GUI
            -- In addition to file creation from a [[]] link, note_id_func is also used by cmp for
            -- working with filenames. Unfortunate, because it means validation cannot be put here
            -- FUTURE: Can this cmp behavior be worked around?
            note_id_func = function(title)
                if title ~= nil then
                    return title
                else
                    ---@diagnostic disable-next-line: return-type-mismatch
                    return nil -- I want the error to return if this happens
                end
            end,
            attachments = {
                img_folder = img_folder,
                ---@param client obsidian.Client
                ---@param path obsidian.Path the absolute path to the image file
                ---@return string
                img_text_func = function(client, path)
                    path = client:vault_relative_path(path) or path
                    return string.format("![%s](%s)", path.name, path)
                end,
                confirm_img_paste = false,
            },
        })

        -- TODO: Might need to map these within the obsidian config so they stick to
        -- Obsidian buffers
        vim.keymap.set("n", "<cr>", function()
            return obsidian.util.smart_action() ---@type string
        end, { expr = true })

        vim.keymap.set("n", "<leader>ss", "<cmd>ObsidianFollowLink hsplit<cr>")
        vim.keymap.set("n", "<leader>sv", "<cmd>ObsidianFollowLink vsplit<cr>")
        vim.keymap.set("n", "<leader>so", "<cmd>ObsidianOpen<cr>")

        vim.keymap.set("n", "<leader>ta", "<cmd>ObsidianBacklinks<cr>")
        vim.keymap.set("n", "<leader>tn", "<cmd>ObsidianLinks<cr>")

        vim.keymap.set("n", "<leader>sr", "<cmd>ObsidianRename<cr>")
        -- TODO Make work in Windows as well
        vim.keymap.set("n", "<leader>si", function()
            local cur_buf_name = vim.api.nvim_buf_get_name(0) ---@type string
            local cur_file_name = vim.fn.fnamemodify(cur_buf_name, ":t:r") ---@type string

            ---@type string
            local cur_workspace = obsidian.get_client().current_workspace.root.filename
            -- TODO: Don't think this would work on Windows
            local img_dir = cur_workspace .. "/" .. img_folder ---@type string
            if vim.fn.isdirectory(img_dir) == 0 then
                vim.fn.mkdir(img_dir, "p")
            end

            -- TODO: Don't think this would work on Windows
            local pattern = img_dir .. "/" .. cur_file_name .. "*.png" ---@type string
            local files = vim.fn.glob(pattern, false, true) ---@type table
            local count = #files ---@type integer

            local padded_count = string.format("%03d", count) ---@type string
            local filename = cur_file_name .. "_" .. padded_count ---@type string

            local made_newline = false
            if not string.match(vim.api.nvim_get_current_line(), "^%s*$") then
                -- If you use feedkeys to input o<esc> for some reason it runs async/after
                -- the ObsidianPasteImg cmd even though it's supposed to be blocking
                vim.cmd("norm! o")
                vim.cmd("stopinsert")
                made_newline = true
            end

            local status, result = pcall(function()
                vim.cmd("ObsidianPasteImg " .. filename)
            end)

            if status then
                -- For reasons I'm unsure of, if you PasteImg, then PasteImg again without saving,
                -- the previously pasted image might be contain no data, even though it's
                -- saved in assets. Seems to happen less if you save after every PasteImg
                vim.cmd("silent up")
                return
            end

            if made_newline then
                -- It would be better in theory to check if there's an image in the clipboard
                -- first, but that function is not exposed, so just unwind on failure
                vim.cmd("norm! u")
            end

            vim.api.nvim_echo(
                { { result or "Unknown error with ObsidianPasteImg" } },
                true,
                { err = true }
            )
        end)

        vim.keymap.set("n", "<leader>sw", function()
            local year = os.date("%Y")
            local month = os.date("%m")
            local day = os.date("%d")
            local date = year .. "-" .. month .. "-" .. day

            return "Go" .. date .. ",,<left><space>"
        end, { expr = true })
    end,
}
