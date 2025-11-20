local api = vim.api
local set = vim.keymap.set
local fzflua_opts = {
    -- LOW: Get out of this preset
    "telescope",
    debug = false,
    files = { no_ignore = true },
    winopts = {
        border = Mjm_Border,
        width = 0.91,
        preview = { horizontal = "right:60%", winopts = { number = true } },
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
    fzf_opts = { ["--tiebreak"] = "length,chunk", ["--algo"] = "v2" },
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
        set("n", "<leader>fr", fzf_lua.registers)

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
        set("n", "<leader>fO", fzf_lua.loclist_stack)
        set("n", "<leader>fq", fzf_lua.quickfix)
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

        api.nvim_create_autocmd("VimEnter", {
            group = api.nvim_create_augroup("fzf-lua-register-ui-select", { clear = true }),
            once = true,
            callback = function()
                api.nvim_cmd({ cmd = "FzfLua", args = { "register_ui_select" } }, {})
            end,
        })
    end,
}

-- LOW: Turn let g:/w:/b:/t: into pickers
-- LOW: Make a thesaurus picker
