local workspaces = {
    {
        name = "main",
        path = "~/obsidian/main",
    },
} ---@type table

-- Only load if we enter a .md file in a defined Obsidian workspace
local note_events = {}
for _, workspace in ipairs(workspaces) do
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
            -- When creating a new file from a [[]] link, use the title in the link
            -- I would like to validate that the title is a valid Windows filename, but
            -- I can't because cmp uses this function when autocompleting [[]] bracket names
            -- TODO: Can the cmp behavior be worked around?
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

        -- TODO: This multi-line checkboxing using visual mode is cool. An alternative would be to
        -- write a custom normal mode motion. go is goto byte. Would look at Nvim gc logic
        -- This is re-written from the plugin's ToggleCheckbox cmd setup and
        -- the toggle_checkbox function specifically. Done so because I don't want to
        -- create a checkbox if one doesn't already exist
        ---@param line_num integer
        ---@return nil
        local toggle_checkbox = function(line_num)
            ---@type string
            local line = vim.api.nvim_buf_get_lines(0, line_num - 1, line_num, false)[1]
            local checkbox_pattern = "^%s*- %[.] " ---@type string
            -- This is where the plugin does alternative logic
            if not string.match(line, checkbox_pattern) then
                return
            end

            -- The rest is lifted basically straight from the plugin
            local client = obsidian.get_client()
            local checkboxes = vim.tbl_keys(client.opts.ui.checkboxes)
            table.sort(checkboxes, function(a, b)
                return (client.opts.ui.checkboxes[a].order or 1000)
                    < (client.opts.ui.checkboxes[b].order or 1000)
            end)

            local enumerate = require("obsidian.itertools").enumerate
            local util = obsidian.util
            for i, check_char in enumerate(checkboxes) do
                if
                    string.match(
                        line,
                        "^%s*- %[" .. util.escape_magic_characters(check_char) .. "%].*"
                    )
                then
                    if i == #checkboxes then
                        i = 0
                    end
                    line = util.string_replace(
                        line,
                        "- [" .. check_char .. "]",
                        "- [" .. checkboxes[i + 1] .. "]",
                        1
                    )
                    break
                end
            end

            vim.api.nvim_buf_set_lines(0, line_num - 1, line_num, true, { line })
        end

        vim.keymap.set("v", "<cr>", function()
            vim.cmd('exec "silent norm! \\<esc>"', {}) -- Update of '< and '> marks
            local start_line = vim.fn.line("'<") ---@type integer
            local end_line = vim.fn.line("'>") ---@type integer
            local bad_start = start_line == 0 or start_line == nil
            local bad_end = end_line == 0 or end_line == nil
            if bad_start or bad_end then
                vim.notify("Visual line marks not updated")
                return
            end

            for i = start_line, end_line do
                toggle_checkbox(i)
            end
            vim.api.nvim_exec2("norm! gv", {})
        end)

        vim.keymap.set("n", "<leader>ss", "<cmd>ObsidianFollowLink hsplit<cr>")
        vim.keymap.set("n", "<leader>sv", "<cmd>ObsidianFollowLink vsplit<cr>")
        vim.keymap.set("n", "<leader>so", "<cmd>ObsidianOpen<cr>")

        vim.keymap.set("n", "<leader>ta", "<cmd>ObsidianBacklinks<cr>")
        vim.keymap.set("n", "<leader>tn", "<cmd>ObsidianLinks<cr>")

        vim.keymap.set("n", "<leader>sr", "<cmd>ObsidianRename<cr>")
        -- TODO Make work in Windows as well
        vim.keymap.set("n", "<leader>si", function()
            local current_file = vim.api.nvim_buf_get_name(0) ---@type string
            local current_file_name = vim.fn.fnamemodify(current_file, ":t:r") ---@type string

            ---@type string
            local cur_workspace = obsidian.get_client().current_workspace.root.filename
            local img_dir = cur_workspace .. "/" .. img_folder ---@type string
            if vim.fn.isdirectory(img_dir) == 0 then
                vim.fn.mkdir(img_dir, "p")
            end

            local pattern = img_dir .. "/" .. current_file_name .. "*.png" ---@type string
            local files = vim.fn.glob(pattern, false, true) ---@type table
            local count = #files ---@type integer

            local padded_count = string.format("%02d", count) ---@type string
            local filename = current_file_name .. "_" .. padded_count ---@type string

            vim.cmd("ObsidianPasteImg " .. filename)
        end)

        ---@return string
        local get_current_file = function()
            local current_file = vim.api.nvim_buf_get_name(0) ---@type string
            if current_file == "" then
                vim.notify("No file in the current buffer.", vim.log.levels.WARN)
                return ""
            end
            if vim.bo.modified then
                vim.notify("Buffer is unsaved.", vim.log.levels.WARN)
                return ""
            end

            return current_file
        end

        ---@param files string[]
        ---@param skip_ext string[]
        ---@return string[]
        local filter_files = function(files, skip_ext)
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

            return vim.tbl_filter(is_valid_ext, files)
        end

        ---@param opts? { goto_next: boolean, skip_ext: string[] }
        ---@return nil
        local next_file_in_dir = function(opts)
            local current_file = get_current_file() ---@type string
            if current_file == "" then
                return
            end

            local dir = vim.fn.expand("%:p:h") ---@type string
            local files = vim.fn.readdir(dir, function(name)
                return vim.fn.isdirectory(dir .. "/" .. name) == 0
            end) ---@type string[]
            table.sort(files)

            opts = vim.deepcopy(opts or {}, true)
            local goto_next = opts.goto_next or false
            local skip_ext = opts.skip_ext or {}

            local filtered_files = filter_files(files, skip_ext) ---@type string[]
            if #filtered_files <= 1 then
                vim.notify("Only one valid file in the directory.", vim.log.levels.INFO)
                return
            end

            -- Make sure we aren't trying to advance out of an invalid extension
            local current_index = nil ---@type integer|nil
            local current_file_name = vim.fn.fnamemodify(current_file, ":t") ---@type string
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
            if goto_next then
                next_index = current_index % #filtered_files + 1
            else
                next_index = (current_index - 2) % #filtered_files + 1
            end

            ---@type string
            local next_file_path = vim.fn.join({ dir, filtered_files[next_index] }, "/")
            vim.cmd("edit " .. vim.fn.fnameescape(next_file_path))
        end

        local skip_extensions = { ".jpg", ".png", ".gif", ".bmp" } ---@type string[]

        -- If it becomes an issue, make these maps check if we're in an obsidian folder
        vim.keymap.set("n", "[o", function()
            next_file_in_dir({ skip_extensions })
        end)
        vim.keymap.set("n", "]o", function()
            next_file_in_dir({ goto_next = true, skip_extensions })
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
