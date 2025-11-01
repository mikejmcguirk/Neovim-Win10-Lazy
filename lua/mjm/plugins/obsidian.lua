-- TODO: markdown-oxide migration:
-- Do new notes go to a specific location? Same dir? (the config doens't let you plug functions
--  into a code action though which is unfortunate)

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
        attachments = {
            confirm_img_paste = false,
            img_folder = img_folder,
            img_text_func = function(path)
                local name = vim.fs.basename(tostring(path))
                local encoded_name = require("obsidian.util").urlencode(name)
                return string.format("![%s](%s)", name, encoded_name)
            end,
        },
        backlinks = {
            parse_headers = true,
        },
        ---@class obsidian.config.CheckboxOpts
        checkbox = {
            -- order = { " ", "~", "!", ">", "x" },
            order = { " ", "x" },
        },
        completion = {
            blink = true,
            create_new = true,
            min_chars = 2,
            nvim_cmp = false,
        },
        daily_notes = nil, -- Not sure about this one either
        disable_frontmatter = true, -- The aliasing creates inconsistent behavior with the GUI
        follow_url_func = nil,
        --- Causes weird ghosting effects with cmp windows
        footer = { enabled = false },
        legacy_commands = false,
        markdown_link_func = nil,
        new_notes_location = "notes_subdir",
        note_frontmatter_func = nil,
        note_id_func = function(title)
            if title ~= nil then
                return title
            else
                ---@diagnostic disable-next-line: return-type-mismatch
                return nil -- I want the error to return if this happens
            end
        end,
        notes_subdir = "notes", -- Not sure what this does
        note_path_func = nil,
        open_notes_in = "current",
        picker = {
            name = "fzf-lua",
            note_mappings = {
                new = "<C-x>",
                insert_link = "<C-l>",
            },
            tag_mappings = {
                tag_note = "<C-x>",
                insert_tag = "<C-l>",
            },
        },
        search_max_lines = 1000,
        sort_by = "modified",
        sort_reversed = true,
        statusline = nil,
        templates = nil,
        ui = { enable = false },
        wiki_link_func = nil,
        workspaces = workspaces,
    })

    vim.api.nvim_create_autocmd("User", {
        pattern = "ObsidianNoteEnter",
        callback = function(ev)
            -- Delete the <CR> map because this overwrites Jump2D
            -- Don't need the conditional operator in Markdown, so the [o ]o defaults can stay
            vim.keymap.del("n", "<CR>", { buffer = ev.buf })

            vim.keymap.set("n", "gf", function()
                return obsidian.util.smart_action()
            end, { buffer = ev.buf, expr = true })

            vim.keymap.set("n", "<leader>ss", function()
                vim.api.nvim_cmd({ cmd = "Obsidian", args = { "follow_link", "hsplit" } }, {})
            end, { buffer = ev.buf })

            vim.keymap.set("n", "<leader>sv", function()
                vim.api.nvim_cmd({ cmd = "Obsidian", args = { "follow_link", "vsplit" } }, {})
            end, { buffer = ev.buf })

            vim.keymap.set("n", "<leader>so", function()
                vim.api.nvim_cmd({ cmd = "Obsidian", args = { "open" } }, {})
            end, { buffer = ev.buf })

            vim.keymap.set("n", "<leader>fab", function()
                vim.api.nvim_cmd({ cmd = "Obsidian", args = { "backliknks" } }, {})
            end, { buffer = ev.buf })

            vim.keymap.set("n", "<leader>fal", function()
                vim.api.nvim_cmd({ cmd = "Obsidian", args = { "links" } }, {})
            end, { buffer = ev.buf })

            vim.keymap.set("n", "<leader>sr", function()
                vim.api.nvim_cmd({ cmd = "Obsidian", args = { "rename" } }, {})
            end, { buffer = ev.buf })

            vim.keymap.set("n", "<leader>si", function()
                ---@type string
                local cur_buf_name = vim.api.nvim_buf_get_name(0)
                ---@type string
                local cur_file_name = vim.fn.fnamemodify(cur_buf_name, ":t:r")

                -- local ws = Obsidian.workspace
                -- local ws_fname = ws.name
                -- local img_dir = ws_fname .. "/" .. img_folder ---@type string
                local img_dir = img_folder ---@type string
                if vim.fn.isdirectory(img_dir) == 0 then vim.fn.mkdir(img_dir, "p") end

                local pattern = img_dir .. "/" .. cur_file_name .. "*.png" ---@type string
                local files = vim.fn.glob(pattern, false, true) ---@type table
                local count = #files ---@type integer

                local padded_count = string.format("%03d", count) ---@type string
                local filename = cur_file_name .. "_" .. padded_count ---@type string

                local made_newline = false
                if not string.match(vim.api.nvim_get_current_line(), "^%s*$") then
                    vim.cmd("norm! o")
                    vim.cmd("stopinsert")
                    made_newline = true
                end

                local status, result = pcall(function()
                    vim.cmd("Obsidian paste_img " .. filename)
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
            end, { buffer = true })
        end,
    })
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
