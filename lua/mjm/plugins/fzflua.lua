local api = vim.api
local set = vim.keymap.set
local fzflua_opts = {
    -- LOW: Get out of this preset
    "telescope",
    debug = false,
    files = {
        no_ignore = true,
    },
    winopts = {
        border = Mjm_Border,
        width = 0.91,
        preview = {
            horizontal = "right:60%",
            winopts = { number = true },
        },
    },
    keymap = {
        builtin = {
            -- Undo Telescope profile mappings
            ["<C-u>"] = false,
            ["<C-d>"] = false,
            -- Avoid shift maps
            -- The ctrl maps are only bound here because ctrl-up/down are not valid
            -- bindings in fzf
            ["<C-up>"] = "preview-page-up",
            ["<C-down>"] = "preview-page-down",
            ["<M-up>"] = "preview-up",
            ["<M-down>"] = "preview-down",
        },
        fzf = {
            ["ctrl-j"] = "ignore",
            ["ctrl-k"] = "kill-line",
            ["alt-j"] = "down",
            ["alt-k"] = "up",
            -- Undo Telescope profile mappings
            ["ctrl-u"] = "unix-line-discard",
            ["ctrl-d"] = false,
            -- Avoid shift maps
            ["alt-up"] = "preview-up",
            ["alt-down"] = "preview-down",
        },
    },
    hls = {
        normal = "NormalFloat",
        preview_normal = "NormalFloat",
        border = "FloatBorder",
        preview_border = "FloatBorder",
        backdrop = "NormalFloat",
    },
    fzf_opts = {
        ["--tiebreak"] = "length,chunk",
        ["--algo"] = "v2",
    },
}

return {
    "ibhagwan/fzf-lua",
    -- LOW: Would be cool if this were lazy loaded. Could put keymaps into a table. But then how
    -- to handle LSP setups
    dependencies = { "nvim-tree/nvim-web-devicons" },
    lazy = false,
    config = function()
        local fzf_lua = require("fzf-lua")
        fzf_lua.setup(fzflua_opts)

        api.nvim_set_hl(0, "FzfLuaScrollBorderFull", { link = "FzfLuaScrollFloatFull" })
        api.nvim_set_hl(0, "FzfLuaScrollFloatEmpty", { link = "FzfLuaScrollFloatFull" })
        api.nvim_set_hl(0, "FzfLuaScrollBorderEmpty", { link = "FzfLuaScrollFloatFull" })
        api.nvim_set_hl(0, "FzfLuaBufFlagCur", { link = "Constant" })
        api.nvim_set_hl(0, "FzfLuaHeaderText", { link = "Constant" })

        -- LOW: Define the keymaps in a table and use them as load triggers
        set("n", "<leader>ff", fzf_lua.resume)

        set("n", "<leader>fb", fzf_lua.buffers)
        set("n", "<leader>fi", fzf_lua.files)

        set("n", "<leader>fgc", fzf_lua.git_commits)
        set("n", "<leader>fgf", fzf_lua.git_files)
        set("n", "<leader>fgh", fzf_lua.git_hunks)
        -- LOW: Why does this not jump? Turning off " jumps doesn't change this
        set("n", "<leader>fgs", fzf_lua.git_status)

        set("n", "<leader>fp", fzf_lua.grep)
        set("n", "<leader>fe", fzf_lua.live_grep)

        set("n", "<leader>fa", fzf_lua.autocmds)
        set("n", "<leader>fc", fzf_lua.command_history)
        set("n", "<leader>ft", fzf_lua.highlights)
        set("n", "<leader>fk", fzf_lua.keymaps)

        set("n", "<leader>fo", fzf_lua.loclist)
        set("n", "<leader>fq", fzf_lua.quickfix)
        set("n", "<leader>fO", fzf_lua.loclist_stack)
        set("n", "<leader>fQ", fzf_lua.quickfix_stack)

        set("n", "<leader>fm", function()
            fzf_lua.marks({
                marks = '[a-z"]',
            })
        end)
        set("n", "<leader>fM", fzf_lua.marks)
        set("n", "<leader>fs", fzf_lua.spellcheck)

        set("n", "<leader>fh", function()
            fzf_lua.helptags({
                fzf_opts = {
                    ["--tiebreak"] = "begin,chunk,length",
                },
            })
        end)

        ---@return boolean|nil, string
        local function get_dict_file()
            local dict = api.nvim_get_option_value("dict", {}) ---@type string
            local dict_file = vim.split(dict, ",")[1] ---@type string
            return vim.uv.fs_access(dict_file, 4), dict_file
        end

        set("n", "<leader>fdd", function()
            local ok, dict_file = get_dict_file() ---@type boolean|nil, string
            if not ok then
                local msg = "Unable to access dictionary file: " .. dict_file ---@type string
                api.nvim_echo({ { msg } }, true, { err = true })
                return
            end

            fzf_lua.fzf_exec("tr -d '\\r' < " .. vim.fn.shellescape(dict_file))
        end)

        local function fuzzy_spell_correct()
            local word = vim.fn.expand("<cword>"):lower() ---@type string
            if word == "" then return vim.notify("No word under cursor", vim.log.levels.WARN) end
            local buf = api.nvim_get_current_buf()

            local ok, dict_file = get_dict_file() ---@type boolean|nil, string
            if not ok then
                local msg = "Unable to access dictionary file: " .. dict_file ---@type string
                api.nvim_echo({ { msg } }, true, { err = true })
                return
            end

            fzf_lua.fzf_exec("tr -d '\\r' < " .. vim.fn.shellescape(dict_file), {
                prompt = 'Suggestions for "' .. word .. '": ',
                actions = {
                    ["default"] = function(selected, _)
                        if not selected or not selected[1] then return end

                        local line = api.nvim_get_current_line()
                        local row_1, col_0 = unpack(api.nvim_win_get_cursor(0))
                        local col_1 = col_0 + 1
                        local search_start = math.max(1, col_1 - #word)
                        local start_col_1 = line:find(word, search_start, false)
                        if not start_col_1 then
                            local err_msg = "Unable to find word boundary for " .. word
                            err_msg = err_msg .. " from cursor position " .. col_1
                            return vim.notify(err_msg, vim.log.levels.ERROR)
                        end

                        if not (start_col_1 <= col_1 and col_1 < start_col_1 + #word) then
                            return vim.notify("Invalid word position (", vim.log.levels.ERROR)
                        end

                        local new_word = selected[1]
                        local row_0 = row_1 - 1
                        local start_col_0 = start_col_1 - 1
                        local end_col_ex = start_col_0 + #word
                        api.nvim_buf_set_text(
                            buf,
                            row_0,
                            start_col_0,
                            row_0,
                            end_col_ex,
                            { new_word }
                        )

                        api.nvim_win_set_cursor(0, { row_1, col_0 })
                        -- Doesn't display for whatever reason
                        -- local msg = 'Replaced "' .. word .. '" with "' .. new_word .. '"'
                        -- api.nvim_echo({ { msg } }, true, {})
                    end,
                    ["ctrl-w"] = function(_, _)
                        local spellfile = vim.fn.stdpath("config") .. "/spell/en.utf-8.add"
                        vim.fn.writefile({ word }, spellfile, "a")
                        api.nvim_cmd({ cmd = "mkspell", args = { spellfile }, bang = true }, {})
                        -- Doesn't display for whatever reason
                        -- local msg = 'Added new word "' .. word .. '" to spellfile as valid'
                        -- api.nvim_echo({ { msg } }, true, {})
                    end,
                },
                -- FUTURE: Would be cool if the previewer tied into wordnet
                previewer = false,
                fzf_opts = {
                    ["--query"] = word,
                    ["--tiebreak"] = "length",
                    ["--algo"] = "v2",
                },
            })
        end

        set("n", "<leader>fds", fuzzy_spell_correct)

        -- PR: This is an easy pull request to make so I don't have to hold onto bespoke code
        -- But this doesn't show the "l"/"c" conversions like :registers does so needs more work
        -- Copy of the original code with vim.fn.getregtype() added
        fzf_lua.registers = function(opts)
            opts = require("fzf-lua.config").normalize_opts(opts, "registers")
            if not opts then return end

            local registers = { [["]], "_", "#", "=", "_", "/", "*", "+", ":", ".", "%" }
            for i = 0, 9 do
                table.insert(registers, tostring(i))
            end

            -- Alphabetical registers
            for i = 65, 90 do
                table.insert(registers, string.char(i))
            end

            if type(opts.filter) == "string" or type(opts.filter) == "function" then
                local filter = type(opts.filter) == "function" and opts.filter
                    or function(r)
                        return r:match(opts.filter) ~= nil
                    end

                registers = vim.tbl_filter(filter, registers)
            end

            local function register_escape_special(reg, nl)
                if not reg then return end

                local gsub_map = {
                    ["\3"] = "^C", -- <C-c>
                    ["\27"] = "^[", -- <Esc>
                    ["\18"] = "^R", -- <C-r>
                }

                for k, v in pairs(gsub_map) do
                    reg = reg:gsub(k, require("fzf-lua.utils").ansi_codes.magenta(v))
                end

                return not nl and reg
                    or nl == 2 and reg:gsub("\n$", "")
                    or reg:gsub("\n", require("fzf-lua.utils").ansi_codes.magenta("\\n"))
            end

            local entries = {}
            for _, r in ipairs(registers) do
                -- pcall in case of invalid data err E5108
                local _, contents = pcall(vim.fn.getreg, r)
                if not contents then return end

                contents = register_escape_special(contents, opts.multiline and 2 or 1)
                local regtype = vim.fn.getregtype(r) or " "
                if (contents and #contents > 0) or not opts.ignore_empty then
                    -- Insert regtype here
                    table.insert(
                        entries,
                        string.format(
                            "[%s] [%s] %s",
                            require("fzf-lua.utils").ansi_codes.yellow(r),
                            require("fzf-lua.utils").ansi_codes.blue(regtype),
                            contents
                        )
                    )
                end
            end

            opts.preview = function(args)
                local r = args[1]:match("%[(.*)%] ")
                local _, contents = pcall(vim.fn.getreg, r)
                return contents and register_escape_special(contents) or args[1]
            end

            require("fzf-lua.core").fzf_exec(entries, opts)
        end

        set("n", "<leader>fr", fzf_lua.registers)

        api.nvim_create_autocmd("VimEnter", {
            group = api.nvim_create_augroup("fzf-lua-register-ui-select", { clear = true }),
            once = true,
            callback = function()
                api.nvim_cmd({ cmd = "FzfLua", args = { "register_ui_select" } }, {})
            end,
        })
    end,
}

-- LOW: Fix ugly colors in scroll area
-- LOW: How to delete qf stacks from FzfLua?
-- LOW: Turn let g:/w:/b:/t: into pickers
-- LOW: Make a thesaurus picker
