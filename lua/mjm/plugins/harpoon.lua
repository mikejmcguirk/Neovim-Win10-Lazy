return {
    {
        "ThePrimeagen/harpoon",
        lazy = false,
        dependencies = { "nvim-lua/plenary.nvim" },
        config = function()
            require("harpoon").setup({
                save_on_toggle = true,

                tabline = true,
                tabline_prefix = "   ",
                tabline_suffix = "   ",
            })

            if Env_Theme == "blue" then
                vim.api.nvim_set_hl(0, "HarpoonInactive", {
                    fg = vim.api.nvim_get_hl(0, { name = "CursorLineNr" }).fg,
                    bg = vim.api.nvim_get_hl(0, { name = "ColorColumn" }).bg,
                })
                vim.api.nvim_set_hl(0, "HarpoonNumberInactive", {
                    fg = "#ffee00",
                    bg = vim.api.nvim_get_hl(0, { name = "ColorColumn" }).bg,
                })
                vim.api.nvim_set_hl(0, "HarpoonActive", {
                    fg = vim.api.nvim_get_hl(0, { name = "CursorLineNr" }).fg,
                    bg = "#30717F",
                })
                vim.api.nvim_set_hl(0, "HarpoonNumberActive", {
                    fg = "#ffee00",
                    bg = "#30717F",
                })
                vim.api.nvim_set_hl(0, "TabLineFill", {
                    fg = vim.api.nvim_get_hl(0, { name = "CursorLineNr" }).fg,
                    bg = vim.api.nvim_get_hl(0, { name = "ColorColumn" }).bg,
                })
            elseif Env_Theme == "green" then
                vim.api.nvim_set_hl(0, "HarpoonActive", {
                    fg = vim.api.nvim_get_hl(0, { name = "DevIconEditorConfig" }).fg,
                    bg = "#5D6262",
                })
                vim.api.nvim_set_hl(0, "HarpoonNumberActive", {
                    fg = vim.api.nvim_get_hl(0, { name = "DevIconEditorConfig" }).fg,
                    bg = "#5D6262",
                })
            else
                vim.api.nvim_set_hl(0, "HarpoonInactive", {
                    fg = vim.api.nvim_get_hl(0, { name = "String" }).fg,
                    bg = vim.api.nvim_get_hl(0, { name = "ColorColumn" }).bg,
                })
                vim.api.nvim_set_hl(0, "HarpoonNumberInactive", {
                    fg = vim.api.nvim_get_hl(0, { name = "Type" }).fg,
                    bg = vim.api.nvim_get_hl(0, { name = "ColorColumn" }).bg,
                })
                vim.api.nvim_set_hl(0, "HarpoonActive", {
                    fg = vim.api.nvim_get_hl(0, { name = "String" }).fg,
                    bg = "#6A4C7F",
                })
                vim.api.nvim_set_hl(0, "HarpoonNumberActive", {
                    fg = vim.api.nvim_get_hl(0, { name = "Type" }).fg,
                    bg = "#6A4C7F",
                })
                vim.api.nvim_set_hl(0, "TabLineFill", {
                    fg = vim.api.nvim_get_hl(0, { name = "String" }).fg,
                    bg = vim.api.nvim_get_hl(0, { name = "ColorColumn" }).bg,
                })
            end

            local marked = require("harpoon.mark")
            local fromUI = require("harpoon.ui")

            vim.keymap.set("n", "<leader>ad", function()
                marked.add_file()
                -- After switching to Lazy, the Harpoon tabline does not automatically update when
                -- a new mark is added. I think this is related to Lazy's lazy execution causing
                -- Harpoon's emit_changed() function to either not run properly or on a delay
                -- The below cmd is a hack to deal with this issue. By running an empty command, it
                -- forces the tabline to redraw
                vim.cmd([[normal! :<esc>]])
            end)

            vim.keymap.set("n", "<leader>ar", function()
                marked.rm_file()

                local contents = {}

                for idx = 1, marked.get_length() do
                    local file = marked.get_marked_file_name(idx)
                    if file == "" then
                    else
                        table.insert(contents, string.format("%s", file))
                    end
                end

                marked.set_mark_list(contents)

                vim.cmd([[normal! :<esc>]])
            end)

            vim.keymap.set("n", "<leader>ae", fromUI.toggle_quick_menu, Opts)

            local function get_or_create_buffer(filename)
                local buf_exists = vim.fn.bufexists(filename) ~= 0

                if buf_exists then
                    return vim.fn.bufnr(filename)
                end

                return vim.fn.bufadd(filename)
            end

            local function windows_nav_file(id)
                require("harpoon.dev").log.trace("nav_file(): Navigating to", id)

                local idx = marked.get_index_of(id)

                if not marked.valid_index(idx) then
                    require("harpoon.dev").log.debug("nav_file(): No mark exists for id", id)
                    return
                end

                local mark = marked.get_marked_file(idx)
                local buf_id

                -- The repo's version of nav_file performs a normalize function on the file name
                -- that converts saved hoots to Unix path formatting. On Windows, because the marks
                -- are saved in Windows file format, the mark in the function does not match the
                -- saved mark and therefore is not recognized by the tabline. This implementation
                -- checks if we are in Windows and does not perform the normalization if we are
                if vim.fn.has("macunix") == 0 then
                    buf_id = get_or_create_buffer(mark.filename)
                else
                    local filename = vim.fs.normalize(mark.filename)
                    buf_id = get_or_create_buffer(filename)
                end

                local set_row = not vim.api.nvim_buf_is_loaded(buf_id)
                local old_bufnr = vim.api.nvim_get_current_buf()

                vim.api.nvim_set_current_buf(buf_id)
                vim.api.nvim_buf_set_option(buf_id, "buflisted", true)

                if set_row and mark.row and mark.col then
                    vim.cmd(string.format(":call cursor(%d, %d)", mark.row, mark.col))

                    require("harpoon.dev").log.debug(
                        string.format(
                            "nav_file(): Setting cursor to row: %d, col: %d",
                            mark.row,
                            mark.col
                        )
                    )
                end

                local old_bufinfo = vim.fn.getbufinfo(old_bufnr)

                if type(old_bufinfo) == "table" and #old_bufinfo >= 1 then
                    old_bufinfo = old_bufinfo[1]
                    local no_name = old_bufinfo.name == ""
                    local one_line = old_bufinfo.linecount == 1
                    local unchanged = old_bufinfo.changed == 0

                    if no_name and one_line and unchanged then
                        vim.api.nvim_buf_delete(old_bufnr, {})
                    end
                end
            end

            for i = 1, 9 do
                vim.keymap.set("n", string.format("<leader>%s", i), function()
                    windows_nav_file(i)
                end, Opts)
            end
        end,
    },
}
