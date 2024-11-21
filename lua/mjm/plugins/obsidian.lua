local skip_extensions = { ".jpg", ".png", ".gif", ".bmp" }

---@param opts? { next_file: boolean, skip_ext: string[] }
---@return nil
local next_file_in_dir = function(opts)
    opts = vim.deepcopy(opts or {}, true)
    local next_file = opts.next_file or false
    local skip_ext = opts.skip_ext or {}

    local current_file = vim.api.nvim_buf_get_name(0) ---@type string
    if current_file == "" then
        vim.notify("No file in the current buffer.", vim.log.levels.WARN)
        return
    end
    if vim.bo.modified then
        vim.notify("Buffer is unsaved.", vim.log.levels.WARN)
        return
    end

    local dir = vim.fn.expand("%:p:h") ---@type string
    local files = vim.fn.readdir(dir) ---@type string[]
    table.sort(files)

    ---@param ext string
    ---@return string
    local normalize_ext = function(ext)
        return ext:gsub("^%.", ""):lower()
    end
    skip_ext = vim.tbl_map(normalize_ext, skip_ext)

    ---@param file string
    ---@return boolean
    local is_valid_ext = function(file)
        local ext = vim.fn.fnamemodify(file, ":e"):lower() ---@type string
        if not skip_ext[ext] then
            return true
        else
            return false
        end
    end
    local filtered_files = vim.tbl_filter(is_valid_ext, files) ---@type string[]

    if #filtered_files <= 1 then
        vim.notify("Only one valid file in the directory.", vim.log.levels.INFO)
        return
    end

    -- Make sure we aren't trying to advance out of an invalid extension
    local current_index = nil ---@type integer|nil
    local current_file_name = vim.fn.fnamemodify(current_file, ":t")
    for idx, file in ipairs(filtered_files) do
        if file == current_file_name then
            current_index = idx
            break
        end
    end
    if not current_index then
        vim.notify("Current file not found in directory listing.", vim.log.levels.WARN)
        return
    end

    local next_index = nil ---@type integer|nil
    if next_file then
        next_index = current_index % #filtered_files + 1
    else
        next_index = (current_index - 2) % #filtered_files + 1
    end

    local next_file_path = vim.fn.join({ dir, filtered_files[next_index] }, "/") ---@type string
    vim.cmd("edit " .. vim.fn.fnameescape(next_file_path))
end

local img_folder = "assets/imgs"

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

        vim.keymap.set("n", "<cr>", "<cmd>ObsidianFollowLink<cr>")
        vim.keymap.set("n", "<leader>ta", "<cmd>ObsidianBacklinks<cr>")
        vim.keymap.set("n", "<leader>tn", "<cmd>ObsidianLinks<cr>")
        vim.keymap.set("n", "<leader>sr", "<cmd>ObsidianRename<cr>")
        vim.keymap.set("n", "<leader>si", function()
            local current_file = vim.api.nvim_buf_get_name(0) ---@type string
            local current_file_name = vim.fn.fnamemodify(current_file, ":t:r")

            local cur_workspace = obsidian.get_client().current_workspace.root.filename
            local img_dir = cur_workspace .. "/" .. img_folder
            if vim.fn.isdirectory(img_dir) == 0 then
                vim.fn.mkdir(img_dir, "p")
            end

            local pattern = img_dir .. "/" .. current_file_name .. "*.png"
            local files = vim.fn.glob(pattern, false, true)
            local count = #files

            local padded_count = string.format("%02d", count)
            local filename = current_file_name .. "_" .. padded_count

            vim.cmd("ObsidianPasteImg " .. filename)
        end)

        -- If it becomes an issue, make these maps check if we're in an obsidian folder
        vim.keymap.set("n", "[o", function()
            next_file_in_dir({ skip_extensions })
        end)
        vim.keymap.set("n", "]o", function()
            next_file_in_dir({ next_file = true, skip_extensions })
        end)
    end,
}
