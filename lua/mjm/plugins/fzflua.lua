-- FUTURE: Turn :let g: into a picker
-- FUTURE: What makes asnc messages not display?

local fzf_lua = require("fzf-lua")
local utils = require("fzf-lua.utils")
local core = require("fzf-lua.core")
local config = require("fzf-lua.config")

fzf_lua.setup({
    "telescope",
    debug = false,
    winopts = {
        border = Border,
        preview = {
            border = Border,
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

vim.keymap.set("n", "<leader>ff", fzf_lua.resume)

vim.keymap.set("n", "<leader>fi", fzf_lua.files)
vim.keymap.set("n", "<leader>fb", fzf_lua.buffers)
vim.keymap.set("n", "<leader>fgf", fzf_lua.git_files)
vim.keymap.set("n", "<leader>fgh", fzf_lua.git_hunks)
vim.keymap.set("n", "<leader>fgs", fzf_lua.git_status)

vim.keymap.set("n", "<leader>fp", fzf_lua.grep)
vim.keymap.set("n", "<leader>fe", fzf_lua.live_grep)

vim.keymap.set("n", "<leader>ft", fzf_lua.highlights)
vim.keymap.set("n", "<leader>fk", fzf_lua.keymaps)
vim.keymap.set("n", "<leader>fc", fzf_lua.command_history)
-- TODO: Add a way to delete individual or all lists from here
vim.keymap.set("n", "<leader>fu", fzf_lua.quickfix_stack)
vim.keymap.set("n", "<leader>fo", fzf_lua.loclist_stack)

vim.keymap.set("n", "<leader>fs", fzf_lua.spellcheck)
vim.keymap.set("n", "<leader>fw", fzf_lua.lsp_live_workspace_symbols)
vim.keymap.set("n", "<leader>fh", function()
    fzf_lua.helptags({
        fzf_opts = {
            ["--tiebreak"] = "begin,chunk,length",
        },
    })
end)

-- FUTURE: Re-add this back in
-- vim.keymap.set("n", "<leader>tl", function()
--     builtin.grep_string({
--         prompt_title = "Help",
--         search = "",
--         search_dirs = vim.api.nvim_get_runtime_file("doc/*.txt", true),
--         only_sort_text = true,
--     })
-- end)

local function fuzzy_spell_correct()
    local word = vim.fn.expand("<cword>") ---@type string
    if word == "" then
        return vim.notify("No word under cursor", vim.log.levels.WARN)
    end

    if vim.fn.spellbadword(word) == "" then
        return vim.notify("'" .. word .. "' is already correct")
    end

    vim.notify("Getting dictionary...")
    local buf = vim.api.nvim_get_current_buf()
    local dict_file = "/usr/share/dict/words"
    fzf_lua.fzf_exec("cat " .. dict_file, {
        prompt = 'Suggestions for "' .. word .. '": ',
        actions = {
            ["default"] = function(selected, _)
                if not selected or not selected[1] then
                    return
                end

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
        previewer = false,
        fzf_opts = {
            ["--query"] = word,
            ["--tiebreak"] = "length",
            ["--algo"] = "v2",
        },
    })
end

vim.keymap.set("n", "<leader>fd", fuzzy_spell_correct)

-- TODO: This is an easy pull request to make so I don't have to hold onto bespoke code
-- But this doesn't show the "l"/"c" conversions like :registers does so needs more work
-- Copy of the original code with vim.fn.getregtype() added
fzf_lua.registers = function(opts)
    opts = config.normalize_opts(opts, "registers")
    if not opts then
        return
    end

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
        if not reg then
            return
        end

        local gsub_map = {
            ["\3"] = "^C", -- <C-c>
            ["\27"] = "^[", -- <Esc>
            ["\18"] = "^R", -- <C-r>
        }

        for k, v in pairs(gsub_map) do
            reg = reg:gsub(k, utils.ansi_codes.magenta(v))
        end

        return not nl and reg
            or nl == 2 and reg:gsub("\n$", "")
            or reg:gsub("\n", utils.ansi_codes.magenta("\\n"))
    end

    local entries = {}
    for _, r in ipairs(registers) do
        -- pcall in case of invalid data err E5108
        local _, contents = pcall(vim.fn.getreg, r)
        contents = register_escape_special(contents, opts.multiline and 2 or 1)
        local regtype = vim.fn.getregtype(r) or " "
        if (contents and #contents > 0) or not opts.ignore_empty then
            -- Insert regtype here
            table.insert(
                entries,
                string.format(
                    "[%s] [%s] %s",
                    utils.ansi_codes.yellow(r),
                    utils.ansi_codes.blue(regtype),
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

    core.fzf_exec(entries, opts)
end

vim.keymap.set("n", "<leader>fr", fzf_lua.registers)
