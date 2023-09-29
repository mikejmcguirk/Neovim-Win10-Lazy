local envTheme = os.getenv("NvimTheme")

local opts = { noremap = true, silent = true }

local themeConfig = function()
    local fm = require "fluoromachine"

    if envTheme == "blue" then
        local function overrides(c)
            return {
                --Keywords (cyan)

                ['@keyword'] = { fg = c.cyan },
                ['@include'] = { fg = c.cyan },
                ['@tag'] = { fg = c.cyan },
                ['@function.macro'] = { fg = c.cyan },

                --Variable Types (purple)

                ['@type'] = { fg = c.purple },
                ['@type.builtin'] = { fg = c.purple },

                ['@variable.lua'] = { fg = c.purple },
                ['@parameter.lua'] = { fg = c.purple },

                --Variable names (white/fg)

                ['@variable.builtin'] = { fg = c.fg },
                ['@parameter'] = { fg = c.fg },
                ['@field'] = { fg = c.fg },

                ['@field.sql'] = { fg = c.fg },

                --Function Calls (Yellow)

                ['@function'] = { fg = c.yellow },
                ['@function.call'] = { fg = c.yellow },
                ['@constructor'] = { fg = c.yellow },
                ['@tag.attribute'] = { fg = c.yellow },

                --Strings & Chars (orange)

                --Number and boolean literals (red, playing neon green)

                ['@number'] = { fg = c.red },
                ['@float'] = { fg = c.red },
                ['@boolean'] = { fg = c.red },

                --Operators (pink)

                ['@operator'] = { fg = c.pink },
                ['@keyword.operator'] = { fg = c.pink },
                ['xmlEqual'] = { fg = c.pink },

                --Brackets, Braces, and Control Flow (green)

                ['@punctuation.bracket'] = { fg = c.green },
                ['@punctuation.delimiter'] = { fg = c.green },
                ['@punctuation.special'] = { fg = c.green },
                ['@keyword.return'] = { fg = c.green },
                ['@tag.delimiter'] = { fg = c.green },

                ['@constructor.lua'] = { fg = c.green },
            }
        end

        fm.setup {
            glow = false,
            brightness = 0.05,
            theme = "retrowave",
            transparent = true,
            colors = function(_, d)
                return {
                    comment = '#3c778c',
                    yellow = '#ffee00',
                    purple = '#f03ea9',
                    pink = '#f17294',
                    alt_bg = '#2f3f4d',
                    currentline = '#2f3f4d',
                    selection = '#3d5161',
                    orange = '#fc7703',
                    red = '#05ed62' --Turn to neon green
                }
            end,

            overrides = overrides
        }

        vim.cmd.colorscheme "fluoromachine"
    elseif envTheme == "green" then
        require("zenburn").setup()

        vim.cmd.colorscheme "zenburn"
    else
        fm.setup {
            glow = false,
            brightness = 0.05,
            theme = "delta",
            transparent = true,
        }

        vim.cmd.colorscheme "fluoromachine"
    end


    if envTheme == "green" then
        vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
    end
    -- Still needed even with fluoromachine transparent = true
    vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })

    vim.api.nvim_set_hl(
        0,
        "Cursorline",
        { bg = vim.api.nvim_get_hl(0, { name = "ColorColumn" }).bg }
    )

    if envTheme == "blue" then
        vim.api.nvim_set_hl(0, '@lsp.type.function', {})
        for _, group in ipairs(vim.fn.getcompletion("@lsp", "highlight")) do
            vim.api.nvim_set_hl(0, group, {})
        end
    end
end

local harpoonConfig = function()
    require("harpoon").setup({
        save_on_toggle = true,

        tabline = true,
        tabline_prefix = "   ",
        tabline_suffix = "   ",
    })


    if envTheme == "blue" then
        vim.api.nvim_set_hl(0,
            "HarpoonInactive", {
                fg = vim.api.nvim_get_hl(0, { name = "CursorLineNr" }).fg,
                bg = vim.api.nvim_get_hl(0, { name = "ColorColumn" }).bg
            }
        )
        vim.api.nvim_set_hl(0,
            "HarpoonNumberInactive", {
                fg = "#ffee00",
                bg = vim.api.nvim_get_hl(0, { name = "ColorColumn" }).bg
            }
        )
        vim.api.nvim_set_hl(0,
            "HarpoonActive", {
                fg = vim.api.nvim_get_hl(0, { name = "CursorLineNr" }).fg,
                bg = "#30717F"
            }
        )
        vim.api.nvim_set_hl(0,
            "HarpoonNumberActive", {
                fg = "#ffee00",
                bg = "#30717F"
            }
        )
        vim.api.nvim_set_hl(0,
            "TabLineFill", {
                fg = vim.api.nvim_get_hl(0, { name = "CursorLineNr" }).fg,
                bg = vim.api.nvim_get_hl(0, { name = "ColorColumn" }).bg
            }
        )
    elseif envTheme == "green" then
        vim.api.nvim_set_hl(0,
            "HarpoonActive", {
                fg = vim.api.nvim_get_hl(0, { name = "DevIconEditorConfig" }).fg,
                bg = "#5D6262"
            }
        )
        vim.api.nvim_set_hl(0,
            "HarpoonNumberActive", {
                fg = vim.api.nvim_get_hl(0, { name = "DevIconEditorConfig" }).fg,
                bg = "#5D6262"
            }
        )
    else
        vim.api.nvim_set_hl(0,
            "HarpoonInactive", {
                fg = vim.api.nvim_get_hl(0, { name = "String" }).fg,
                bg = vim.api.nvim_get_hl(0, { name = "ColorColumn" }).bg
            }
        )
        vim.api.nvim_set_hl(0,
            "HarpoonNumberInactive", {
                fg = vim.api.nvim_get_hl(0, { name = "Type" }).fg,
                bg = vim.api.nvim_get_hl(0, { name = "ColorColumn" }).bg
            }
        )
        vim.api.nvim_set_hl(0,
            "HarpoonActive", {
                fg = vim.api.nvim_get_hl(0, { name = "String" }).fg,
                bg = "#6A4C7F"
            }
        )
        vim.api.nvim_set_hl(0,
            "HarpoonNumberActive", {
                fg = vim.api.nvim_get_hl(0, { name = "Type" }).fg,
                bg = "#6A4C7F"
            }
        )
        vim.api.nvim_set_hl(0,
            "TabLineFill", {
                fg = vim.api.nvim_get_hl(0, { name = "String" }).fg,
                bg = vim.api.nvim_get_hl(0, { name = "ColorColumn" }).bg
            }
        )
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

    vim.keymap.set("n", "<leader>ae", fromUI.toggle_quick_menu, opts)

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
        if vim.fn.has('macunix') == 0 then
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
        end, opts)
    end
end

local lualineConfig = function()
    local theme

    if envTheme == "blue" then
        local old_auto = require 'lualine.themes.auto'
        local custom_auto = require 'lualine.themes.auto'

        local old_auto_visual_a_bg = old_auto.visual.a.bg
        local old_auto_visual_b_bg = old_auto.visual.b.bg
        -- local old_auto_visual_c_bg = old_auto.visual.c.bg

        local old_auto_normal_a_bg = old_auto.normal.a.bg
        local old_auto_normal_b_bg = old_auto.normal.b.bg
        -- local old_auto_normal_c_bg = old_auto.normal.c.bg

        local old_auto_visual_a_fg = old_auto.visual.a.fg
        local old_auto_visual_b_fg = old_auto.visual.b.fg
        -- local olllluto_visual_c_fg = old_auto.visual.c.fg

        local old_auto_normal_a_fg = old_auto.normal.a.fg
        local old_auto_normal_b_fg = old_auto.normal.b.fg
        -- local old_auto_normal_c_fg = old_auto.normal.c.fg

        custom_auto.visual.a.bg = old_auto_normal_a_bg
        custom_auto.visual.b.bg = old_auto_normal_b_bg
        --custom_auto.visual.c.bg = old_auto_normal_c_bg

        custom_auto.normal.a.bg = old_auto_visual_a_bg
        custom_auto.normal.b.bg = old_auto_visual_b_bg
        --custom_auto.normal.c.bg = old_auto_visual_c_bg

        custom_auto.visual.a.fg = old_auto_normal_a_fg
        custom_auto.visual.b.fg = old_auto_normal_b_fg
        --custom_auto.visual.c.fg = old_auto_normal_c_fg

        custom_auto.normal.a.fg = old_auto_visual_a_fg
        custom_auto.normal.b.fg = old_auto_visual_b_fg

        theme = custom_auto
    elseif envTheme == "green" then
        theme = "zenburn"
    else
        theme = "fluoromachine"
    end

    require('lualine').setup {
        sections = {
            lualine_a = { 'branch' },
            lualine_b = { '%h %F %m' },
            lualine_c = { 'diagnostics' },
            lualine_x = { 'encoding', 'fileformat', 'filetype' },
            lualine_y = { 'progress' },
            lualine_z = { '%l/%L : %c : %o' }
        },
        inactive_sections = {
            lualine_a = {},
            lualine_b = { 'filename' },
            lualine_c = { 'diagnostics' },
            lualine_x = { 'filetype' },
            lualine_y = { 'progress' },
            lualine_z = {}
        },
        options = {
            -- section_separators = { '', '' },
            -- component_separators = { '', '' },
            section_separators = { '', '' },
            component_separators = { '', '' },
            theme = theme
        },
    }
end

return {
    {
        "maxmx03/fluoromachine.nvim",
        lazy = false,    -- Does not work with lazy loading
        priority = 1000, -- Set top priority so highlight groups load
    },
    {
        "phha/zenburn.nvim",
        lazy = false,
        priority = 999,
        config = function()
            themeConfig()
        end
    },
    {
        "ThePrimeagen/harpoon",
        lazy = false,
        priority = 998,
        dependencies = { "nvim-lua/plenary.nvim" },
        config = function()
            harpoonConfig()
        end
    },
    {
        "unblevable/quick-scope",
        lazy = false,
        priority = 997,
        config = function()
            if not envTheme or envTheme == "delta" then
                vim.api.nvim_set_hl(0, "QuickScopePrimary",
                    { bg = "#98FFFB", fg = "#000000", ctermbg = 14, ctermfg = 0 })
                vim.api.nvim_set_hl(0, "QuickScopeSecondary",
                    { bg = "#FF67D4", fg = "#000000", ctermbg = 207, ctermfg = 0 })
            elseif envTheme == "blue" then
                vim.api.nvim_set_hl(0, "QuickScopePrimary",
                    { bg = "#98FFFB", fg = "#000000", ctermbg = 14, ctermfg = 0 })
                vim.api.nvim_set_hl(0, "QuickScopeSecondary",
                    { bg = "#EDFF98", fg = "#000000", ctermbg = 226, ctermfg = 0 })
            end
        end,
    },
    {
        'nvim-lualine/lualine.nvim',
        dependencies = { 'nvim-tree/nvim-web-devicons' },
        lazy = false,
        priority = 996,
        config = function()
            lualineConfig()
        end
    },

}
