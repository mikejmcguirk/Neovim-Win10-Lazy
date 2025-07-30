-- Only load if we enter a .md file in a defined Obsidian workspace
local note_paths = {}
local workspaces = {
    {
        name = "main",
        path = "~/Documents/obsidian/main",
    },
} ---@type table

for _, workspace in pairs(workspaces) do
    table.insert(note_paths, vim.fn.expand(workspace.path) .. "/*.md")
end

local function load_obsidian()
    local img_folder = "assets/imgs"

    local obsidian = require("obsidian")
    obsidian.setup({
        workspaces = workspaces,
        picker = {
            -- Set your preferred picker. Can be one of 'telescope.nvim', 'fzf-lua', or 'mini.pick'.
            name = "fzf-lua",
            -- Optional, configure key mappings for the picker. These are the defaults.
            -- Not all pickers support all mappings.
            note_mappings = {
                -- Create a new note from your query.
                new = "<C-x>",
                -- Insert a link to the selected note.
                insert_link = "<C-l>",
            },
            tag_mappings = {
                -- Add tag(s) to current note.
                tag_note = "<C-x>",
                -- Insert a tag at the current location.
                insert_tag = "<C-l>",
            },
        },
        mappings = {
            ["<cr>"] = {
                action = function()
                    return obsidian.util.smart_action()
                end,
                opts = { buffer = true, expr = true },
            },
            ["<leader>ss"] = {
                action = function()
                    vim.cmd("ObsidianFollowLink hsplit")
                end,
                opts = { buffer = true },
            },
            ["<leader>sv"] = {
                action = function()
                    vim.cmd("ObsidianFollowLink vsplit")
                end,
                opts = { buffer = true },
            },
            ["<leader>so"] = {
                action = function()
                    vim.cmd("ObsidianOpen")
                end,
                opts = { buffer = true },
            },
            ["<leader>fab"] = {
                action = function()
                    vim.cmd("ObsidianBacklinks")
                end,
                opts = { buffer = true },
            },
            ["<leader>fal"] = {
                action = function()
                    vim.cmd("ObsidianLinks")
                end,
                opts = { buffer = true },
            },
            ["<leader>sr"] = {
                action = function()
                    vim.cmd("ObsidianRename")
                end,
                opts = { buffer = true },
            },
            ["<leader>si"] = {
                -- FUTURE: Make this work with Windows
                action = function()
                    ---@type string
                    local cur_buf_name = vim.api.nvim_buf_get_name(0)
                    ---@type string
                    local cur_file_name = vim.fn.fnamemodify(cur_buf_name, ":t:r")

                    ---@type string
                    local cur_workspace = obsidian.get_client().current_workspace.root.filename
                    local img_dir = cur_workspace .. "/" .. img_folder ---@type string
                    if vim.fn.isdirectory(img_dir) == 0 then
                        vim.fn.mkdir(img_dir, "p")
                    end

                    local pattern = img_dir .. "/" .. cur_file_name .. "*.png" ---@type string
                    local files = vim.fn.glob(pattern, false, true) ---@type table
                    local count = #files ---@type integer

                    local padded_count = string.format("%03d", count) ---@type string
                    local filename = cur_file_name .. "_" .. padded_count ---@type string

                    local made_newline = false
                    if not string.match(vim.api.nvim_get_current_line(), "^%s*$") then
                        -- If you use feedkeys to input o<esc> for some reason it runs
                        -- async/after the ObsidianPasteImg cmd even though it's supposed
                        -- to be blocking
                        vim.cmd("norm! o")
                        vim.cmd("stopinsert")
                        made_newline = true
                    end

                    local status, result = pcall(function()
                        vim.cmd("ObsidianPasteImg " .. filename)
                    end)

                    if status then
                        -- For reasons I'm unsure of, if you PasteImg, then PasteImg again
                        -- without saving, the previously pasted image might be contain no
                        -- data, even though it's saved in assets. Seems to happen less if
                        -- you save after every PasteImg
                        vim.cmd("silent up")
                        return
                    end

                    if made_newline then
                        -- It would be better in theory to check if there's an image in the
                        -- clipboard first, but that function is not exposed, so just
                        -- unwind on failure
                        vim.cmd("norm! u")
                    end

                    vim.api.nvim_echo(
                        { { result or "Unknown error with ObsidianPasteImg" } },
                        true,
                        { err = true }
                    )
                end,
                opts = { buffer = true },
            },
        },
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

    -- This doesn't play nice with Obsidian's config table
    vim.keymap.set("n", "<leader>sw", function()
        local year = os.date("%Y")
        local month = os.date("%m")
        local day = os.date("%d")
        local date = year .. "-" .. month .. "-" .. day

        return "Go" .. date .. ",,<left><space>"
    end, { expr = true })
end

local obsidian_group = vim.api.nvim_create_augroup("load-obsidian", { clear = true })
for _, event in pairs(note_paths) do
    vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile" }, {
        pattern = event,
        group = obsidian_group,
        once = true,
        callback = function()
            load_obsidian()
            vim.api.nvim_clear_autocmds({ group = obsidian_group })
        end,
    })
end
