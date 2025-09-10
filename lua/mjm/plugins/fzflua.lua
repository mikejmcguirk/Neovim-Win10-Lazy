--- TODO: Move to gi mappings
--- --- My gI map goes to <M-i>. Default gi can be lost
--- giq and giQ for qflist and qf stack
--- gil and giL for loclist and loclist stack
--- --- Add logic to redirect to chistory and lhistory if fzflua not present
--- TODO: Add #fzflua tag where needed
--- FUTURE: Turn :let g: into a picker
--- LOW: What makes async messages not display?

local fzf_lua = require("fzf-lua")

fzf_lua.setup({
    "telescope",
    debug = false,
    files = {
        no_ignore = true,
    },
    winopts = {
        border = Border,
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
})

vim.api.nvim_set_hl(0, "FzfLuaScrollBorderFull", { link = "FzfLuaScrollFloatFull" })
vim.api.nvim_set_hl(0, "FzfLuaScrollFloatEmpty", { link = "FzfLuaScrollFloatFull" })
vim.api.nvim_set_hl(0, "FzfLuaScrollBorderEmpty", { link = "FzfLuaScrollFloatFull" })
vim.api.nvim_set_hl(0, "FzfLuaBufFlagCur", { link = "Constant" })
vim.api.nvim_set_hl(0, "FzfLuaHeaderText", { link = "Constant" })

-- Obsidian pickers are set to "fa"

Map("n", "<leader>ff", fzf_lua.resume)

Map("n", "<leader>fb", fzf_lua.buffers)
Map("n", "<leader>fi", fzf_lua.files)

Map("n", "<leader>fgc", fzf_lua.git_commits)
Map("n", "<leader>fgf", fzf_lua.git_files)
Map("n", "<leader>fgh", fzf_lua.git_hunks)
Map("n", "<leader>fgs", fzf_lua.git_status)

Map("n", "<leader>fp", fzf_lua.grep)
Map("n", "<leader>fe", fzf_lua.live_grep)

Map("n", "<leader>fa", fzf_lua.autocmds)
Map("n", "<leader>fc", fzf_lua.command_history)
Map("n", "<leader>ft", fzf_lua.highlights)
Map("n", "<leader>fk", fzf_lua.keymaps)

-- LOW: Add a way to delete individual or all lists from here
Map("n", "<leader>fo", fzf_lua.loclist)
Map("n", "<leader>fu", fzf_lua.quickfix)
Map("n", "<leader>fO", fzf_lua.loclist_stack)
Map("n", "<leader>fU", fzf_lua.quickfix_stack)

local buf_marks = function()
    require("fzf-lua").marks({
        marks = '[a-z"]',
    })
end

Map("n", "<leader>fm", buf_marks)
Map("n", "<leader>fM", fzf_lua.marks)
Map("n", "<leader>fs", fzf_lua.spellcheck)

local helptags = function()
    fzf_lua.helptags({
        fzf_opts = {
            ["--tiebreak"] = "begin,chunk,length",
        },
    })
end
Map("n", "<leader>fh", helptags)

-- TODO: Helpgrep might assist us here. Can make go giH
-- LOW: Re-add this back in
-- Map("n", "<leader>tl", function()
--     builtin.grep_string({
--         prompt_title = "Help",
--         search = "",
--         search_dirs = vim.api.nvim_get_runtime_file("doc/*.txt", true),
--         only_sort_text = true,
--     })
-- end)

local function fuzzy_dict()
    -- FUTURE: This should merge the results form all dictionary files
    --- @diagnostic disable: undefined-field
    local dict_file = vim.opt.dictionary:get()[1]
    local file = io.open(dict_file, "r")
    if not file then
        return vim.notify("Unable to open dictionary file: " .. dict_file, vim.log.levels.ERROR)
    end
    file:close()

    fzf_lua.fzf_exec("tr -d '\\r' < " .. vim.fn.shellescape(dict_file))
end

local function fuzzy_spell_correct()
    local word = vim.fn.expand("<cword>"):lower() ---@type string
    if word == "" then return vim.notify("No word under cursor", vim.log.levels.WARN) end

    local buf = vim.api.nvim_get_current_buf()

    -- FUTURE: This should merge the results form all dictionary files
    --- @diagnostic disable: undefined-field
    local dict_file = vim.opt.dictionary:get()[1]
    local file = io.open(dict_file, "r")
    if not file then
        return vim.notify("Unable to open dictionary file: " .. dict_file, vim.log.levels.ERROR)
    end
    file:close()

    fzf_lua.fzf_exec("tr -d '\\r' < " .. vim.fn.shellescape(dict_file), {
        prompt = 'Suggestions for "' .. word .. '": ',
        actions = {
            ["default"] = function(selected, _)
                if not selected or not selected[1] then return end

                local line = vim.api.nvim_get_current_line()
                local row_1, col_0 = unpack(vim.api.nvim_win_get_cursor(0))
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
                vim.api.nvim_buf_set_text(buf, row_0, start_col_0, row_0, end_col_ex, { new_word })

                vim.api.nvim_win_set_cursor(0, { row_1, col_0 })
                -- Doesn't display for whatever reason
                -- local msg = 'Replaced "' .. word .. '" with "' .. new_word .. '"'
                -- vim.api.nvim_echo({ { msg } }, true, {})
            end,
            ["ctrl-w"] = function(_, _)
                vim.fn.writefile({ word }, SpellFile, "a")
                vim.cmd("mkspell! " .. SpellFile)
                -- Doesn't display for whatever reason
                -- local msg = 'Added new word "' .. word .. '" to spellfile as valid'
                -- vim.api.nvim_echo({ { msg } }, true, {})
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

Map("n", "<leader>fdd", fuzzy_dict)
Map("n", "<leader>fds", fuzzy_spell_correct)

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
            or function(r) return r:match(opts.filter) ~= nil end

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

Map("n", "<leader>fr", fzf_lua.registers)
