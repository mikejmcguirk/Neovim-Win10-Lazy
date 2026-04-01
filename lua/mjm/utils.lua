-- From mini.jump2D. Extremely useful
-- local max_width = vim.o.columns * math.max(vim.o.cmdheight - 1, 0) + vim.v.echospace

mjm.util = {}

local api = vim.api
local fn = vim.fn
local uv = vim.uv

---@class MjmUtils
local M = {}

---@param prompt string
---@return boolean, string
function M.get_input(prompt)
    local ok, result = pcall(fn.input, { prompt = prompt, cancelreturn = "" })
    if (not ok) and result == "Keyboard interrupt" then
        return true, ""
    else
        return ok, result
    end
end

-- Adapted from the source's "prepare_help_buffer" function

---@param buf integer
---@return nil
local function prep_help_buf(buf)
    -- NOTE: Do not manually set filetype here. Unsure why, but it makes local opts set improperly
    api.nvim_set_option_value("bt", "help", { buf = buf })
    -- Have observed inconsistent behavior with these options on their own. Just set always
    api.nvim_set_option_value("bl", false, { buf = buf })
    api.nvim_set_option_value("bin", false, { buf = buf })
    api.nvim_set_option_value("ma", false, { buf = buf })
    api.nvim_set_option_value("ts", 8, { buf = buf })
end

---@param win integer
---@return nil
local function setup_help_win(win)
    api.nvim_win_call(win, function()
        -- api.set_option_value("iskeyword", '!-~,^*,^|,^",192-255', { scope = "local" })
        api.nvim_set_option_value("fdm", "manual", { scope = "local" })
        api.nvim_set_option_value("list", false, { scope = "local" })
        api.nvim_set_option_value("arabic", false, { scope = "local" })
        api.nvim_set_option_value("rl", false, { scope = "local" })
        api.nvim_set_option_value("fen", false, { scope = "local" })
        api.nvim_set_option_value("diff", false, { scope = "local" })
        api.nvim_set_option_value("spell", false, { scope = "local" })
    end)

    api.nvim_set_option_value("scb", false, { win = win })
end

---@class mjm.OpenBufSource
---@field bufnr? integer
---@field file? string

---@class mjm.OpenBufOpts
---@field buftype? string
---@field clearjumps? boolean
---@field cur_pos? {[1]: integer, [2]: integer}
---@field force? boolean
---@field open? "vsplit"|"split"|"tabnew"
---@field win? integer
---@field skip_zz? boolean

---@param source mjm.OpenBufSource
---@param opts mjm.OpenBufOpts
---@return boolean
--- Using bufload breaks BufReadPost autocmds and opt_local setup
--- nvim_set_current_buf will load the buf properly if it needs to
--- nvim_win_set_buf does the same, and also automatically moves the user into that window
function M.open_buf(source, opts)
    source = source or {}
    local buf = (function()
        if source.bufnr then
            return source.bufnr
        elseif source.file then
            return fn.bufadd(source.file)
        else
            return nil
        end
    end)()

    if not buf then
        local chunk = { "Unable to resolve buf in open_buf", "ErrorMsg" }
        api.nvim_echo({ chunk }, true, { err = true })
        return false
    end

    local cur_buf = api.nvim_get_current_buf()
    local same_buf = cur_buf == buf
    if (not opts.force) and same_buf then
        api.nvim_echo({ { "Already in buffer", "" } }, false, {})
        return true
    end

    opts = opts or {}
    if opts.open == "vsplit" then
        ---@diagnostic disable: missing-fields
        api.nvim_cmd({ cmd = "vsplit" }, {})
    elseif opts.open == "split" then
        api.nvim_cmd({ cmd = "split" }, {})
    elseif opts.open == "tabnew" then
        api.nvim_cmd({ cmd = "tabnew" }, {})
        local tabnew_win = api.nvim_get_current_win()
        local tabnew_buf = api.nvim_win_get_buf(tabnew_win)
        if require("nvim-tools.buf").is_empty_noname(tabnew_buf) then
            api.nvim_set_option_value("bufhidden", "wipe", { buf = tabnew_buf })
        end
    end

    local win = opts.win or api.nvim_get_current_win() ---@type integer
    if not api.nvim_win_is_valid(win) then
        return false
    end
    local already_open = api.nvim_win_get_buf(win) == buf ---@type boolean
    if not already_open then
        if opts.buftype == "help" then
            prep_help_buf(buf)
        else
            api.nvim_set_option_value("bl", true, { buf = buf })
        end

        api.nvim_win_call(win, function()
            -- This loads the buf if necessary. Do not use bufload
            api.nvim_set_current_buf(buf)
            if opts.clearjumps then
                api.nvim_cmd({ cmd = "clearjumps" }, {})
            end
        end)

        if opts.buftype == "help" then
            setup_help_win(win)
        end
    end

    if opts.cur_pos then
        if already_open then
            api.nvim_win_call(win, function()
                api.nvim_cmd({ cmd = "normal", args = { "m'" }, bang = true }, {})
            end)
        end

        require("nvim-tools.win").protected_set_cursor(win, opts.cur_pos)
    end

    if not opts.skip_zz then
        api.nvim_win_call(win, function()
            vim.api.nvim_cmd({ cmd = "normal", args = { "zz" }, bang = true }, {})
        end)
    end

    api.nvim_win_call(win, function()
        api.nvim_cmd({ cmd = "normal", args = { "zv" }, bang = true }, {})
    end)

    return true
end
-- TODO: Create nvim-tools window split
-- TODO: Replace with nvim-tools function

---@param buf integer
---@param indent integer
---@return nil
function M.set_buf_space_indent(buf, indent)
    api.nvim_set_option_value("ts", indent, { buf = buf })
    api.nvim_set_option_value("sts", indent, { buf = buf })
    api.nvim_set_option_value("sw", indent, { buf = buf })
end

---@param buf number
---@param start_idx number
---@param end_idx number
---@return nil
local function fix_bookend_blanks(buf, start_idx, end_idx)
    local line = api.nvim_buf_get_lines(buf, start_idx, end_idx, true)[1] ---@type string
    local blank_line = (line == "") or line:match("^%s*$") ---@type any
    local last_line = api.nvim_buf_line_count(buf) == 1 ---@type boolean

    if last_line or not blank_line then
        return
    end

    api.nvim_buf_set_lines(buf, start_idx, end_idx, false, {})
    fix_bookend_blanks(buf, start_idx, end_idx)
end

---@class mjm.util.FallbackFormatterOpts
---@field retab boolean

---@param buf integer
---@param opts? mjm.util.FallbackFormatterOpts
---@return nil
function M.fallback_formatter(buf, opts)
    buf = buf == 0 and api.nvim_get_current_buf() or buf
    opts = opts or {}
    if opts.retab == nil then
        opts.retab = true
    end

    local get_option_value = api.nvim_get_option_value
    local shiftwidth = get_option_value("sw", { buf = buf }) ---@type integer
    local expandtab = get_option_value("et", { buf = buf }) ---@type boolean
    if shiftwidth == 0 then
        shiftwidth = get_option_value("ts", { buf = buf })
    end

    if expandtab and opts.retab then
        local set_option_value = api.nvim_set_option_value
        set_option_value("ts", shiftwidth, { buf = buf })
        set_option_value("sts", shiftwidth, { buf = buf })
        api.nvim_buf_call(buf, function()
            api.nvim_cmd({ cmd = "retab" }, {})
        end)
    end

    fix_bookend_blanks(buf, 0, 1)
    fix_bookend_blanks(buf, -2, -1)

    local total_lines = api.nvim_buf_line_count(buf) ---@type integer
    local lines = api.nvim_buf_get_lines(buf, 0, total_lines, true) ---@type string[]

    local consecutive_blanks = 0 ---@type integer
    local lines_removed = 0 ---@type integer

    ---@param iter number
    ---@param line string
    ---@return nil
    local format_line = function(iter, line)
        local row_0 = iter - lines_removed - 1 ---@type number
        local line_len = #line ---@type integer
        local empty_line = line == "" ---@type boolean
        local whitespace_line = line:match("^%s+$") ---@type any
        local blank_line = empty_line or whitespace_line ---@type any

        if blank_line then
            consecutive_blanks = consecutive_blanks + 1
        else
            consecutive_blanks = 0
        end

        if blank_line and consecutive_blanks > 1 then
            api.nvim_buf_set_lines(buf, row_0, row_0 + 1, false, {})
            lines_removed = lines_removed + 1

            return
        end

        if whitespace_line then
            api.nvim_buf_set_text(buf, row_0, 0, row_0, line_len, {})
            return
        end

        local last_non_blank, _ = line:find("(%S)%s*$") ---@type integer|nil
        if last_non_blank and last_non_blank ~= line_len then
            api.nvim_buf_set_text(buf, row_0, last_non_blank, row_0, line_len, {})
        end

        local first_non_blank, _ = line:find("%S") or 1, nil ---@type integer, nil
        first_non_blank = first_non_blank - 1
        local extra_spaces = first_non_blank % shiftwidth ---@type unknown
        if extra_spaces == 0 or not expandtab then
            return
        end

        local half_shiftwidth = shiftwidth * 0.5 ---@type unknown
        local round_up = extra_spaces >= half_shiftwidth ---@type boolean
        if round_up then
            local new_spaces = shiftwidth - extra_spaces
            local spaces = string.rep(" ", new_spaces)
            api.nvim_buf_set_text(buf, row_0, 0, row_0, 0, { spaces })
        else
            api.nvim_buf_set_text(buf, row_0, 0, row_0, extra_spaces, {})
        end
    end

    for i, line in ipairs(lines) do
        format_line(i, line)
    end
end

-- Taken from nvim-overfly
-- FUTURE: If I understand the Neovim repo code right, at some point a "highest" filter will be
-- added to diagnostic jumping
-- PR: Or add it if not
---@param opts? {buf:integer|nil}
---@return integer|nil
function M.get_top_severity(opts)
    opts = opts or {}
    local has_warn = false ---@type boolean
    local has_info = false ---@type boolean
    local has_hint = false ---@type boolean

    for _, d in ipairs(vim.diagnostic.get(opts.buf or nil)) do
        if d.severity == vim.diagnostic.severity.ERROR then
            return vim.diagnostic.severity.ERROR
        elseif d.severity == vim.diagnostic.severity.WARN then
            has_warn = true
        elseif d.severity == vim.diagnostic.severity.INFO then
            has_info = true
        elseif d.severity == vim.diagnostic.severity.HINT then
            has_hint = true
        end
    end

    if has_warn then
        return vim.diagnostic.severity.WARN
    elseif has_info then
        return vim.diagnostic.severity.INFO
    elseif has_hint then
        return vim.diagnostic.severity.HINT
    else
        return nil
    end
end

---@return nil
function M.check_word_under_cursor()
    local word = fn.expand("<cword>") ---@type string
    if word == "" then
        api.nvim_echo({ { "No word under cursor" } }, false, {})
        return
    end

    vim.system({ "wn", word, "-over" }, { text = true, timeout = 1000 }, function(out)
        vim.schedule(function()
            local lines = vim.split(out.stdout, "\n") ---@type string[]
            if out.code <= 0 or #lines < 0 then
                ---@type string
                local msg = out.code < 0 and "Error checking Wordnet: " .. out.stderr
                    or "No results from Wordnet"
                api.nvim_echo({ { msg } }, false, { err = out.code < 0 })
                return
            end

            for _, line in ipairs(lines) do
                line = line:match("^%s*(.-)%s*$")
            end

            vim.lsp.util.open_floating_preview(lines, "markdown")
        end)
    end)
end

-- Adapted from mike-jl/harpoonEx
---@param opts {buf?: integer, bufname?: string}
---@return nil
function M.harpoon_rm_buf(opts)
    opts = opts or {}

    local full_bufname = (function()
        if opts.bufname then
            return fn.fnamemodify(opts.bufname, ":p")
        elseif opts.buf then
            return fn.fnamemodify(api.nvim_buf_get_name(opts.buf), ":p")
        else
            return nil
        end
    end)()

    if not full_bufname then
        return
    end

    local ok, harpoon = pcall(require, "harpoon")
    if (not ok) or not harpoon then
        api.nvim_echo({ { "Unable to require harpoon", "ErrorMsg" } }, true, { err = true })
    end

    local list = harpoon:list()
    if not list then
        return
    end

    local items = list.items
    local idx = nil

    for i, t in ipairs(items) do
        local item = fn.fnamemodify(t.value, ":p")
        if full_bufname == item then
            idx = i
            break
        end
    end

    if not idx then
        return
    end

    table.remove(list.items, idx)
    list._length = list._length - 1

    local extensions = require("harpoon.extensions")
    extensions.extensions:emit(extensions.event_names.REMOVE)
end

---@param old_bufname string
---@param new_bufname string
function M.harpoon_mv_buf(old_bufname, new_bufname)
    local ok, harpoon = pcall(require, "harpoon")
    if (not ok) or not harpoon then
        api.nvim_echo({ { "Unable to require harpoon", "ErrorMsg" } }, true, {})
    end

    local list = harpoon:list()
    if not list then
        return
    end

    local items = list.items
    if #items < 1 then
        return
    end

    local full_old_bufname = fn.fnamemodify(old_bufname, ":p")
    local idx = nil

    for i, t in ipairs(items) do
        local item = fn.fnamemodify(t.value, ":p")
        if item == full_old_bufname then
            idx = i
            break
        end
    end

    if not idx then
        return
    end

    local full_new_bufname = fn.fnamemodify(new_bufname, ":p")
    local relative_new_bufname = fn.fnamemodify(full_new_bufname, ":.")
    list.items[idx].value = relative_new_bufname

    local extensions = require("harpoon.extensions")
    extensions.extensions:emit(extensions.event_names.REMOVE)
end

---@return integer[]
local function get_listed_bufs()
    local bufs = api.nvim_list_bufs() ---@type integer[]
    local listed_bufs = {} ---@type integer[]
    for _, buf in ipairs(bufs) do
        if api.nvim_get_option_value("bl", { buf = buf }) then
            listed_bufs[#listed_bufs + 1] = buf
        end
    end

    return listed_bufs
end

-- https://github.com/neovim/neovim/pull/33402
-- When nvim_buf_delete is run without the unload flag, it goes beyond
-- deleting the buffer into deleting shada state, including the '"' mark
-- FUTURE: Whenever nvim_buf_del is created, use that for deleting buffers

function M.is_empty_buf(buf)
    if api.nvim_buf_line_count(buf) > 1 then
        return false
    end

    local first_line = api.nvim_buf_get_lines(buf, 0, 1, false) ---@type string[]
    if (not first_line[1]) or #first_line[1] == 0 then
        return true
    else
        return false
    end
end

---@param buf integer
---@param force boolean
---@param wipeout boolean
---@param no_save boolean
---@param suppress_errs boolean
---@return boolean, [string, string|integer?][]|nil, boolean|nil, vim.api.keyset.echo_opts|nil
function M.pbuf_rm(buf, force, wipeout, no_save, suppress_errs)
    vim.validate("buf", buf, "number")
    vim.validate("force", force, "boolean")
    vim.validate("wipeout", wipeout, "boolean")

    if not api.nvim_buf_is_valid(buf) then
        local chunks = { { "Buf " .. buf .. " is not valid" } } ---@type [string,string|integer?][]
        if suppress_errs then
            return true, nil, nil, nil
        end

        return false, chunks, true, { err = true }
    end

    if #api.nvim_buf_get_name(buf) == 0 and not force and not M.is_empty_buf(buf) then
        if suppress_errs then
            return true, nil, nil, nil
        end

        local chunks = { { "Buf " .. " has no filename" } }
        return false, chunks, true, { err = true }
    end

    local delete_opts = { force = force }
    if not wipeout then
        local listed_bufs = get_listed_bufs()
        for i = 1, #listed_bufs, -1 do
            if listed_bufs[i] == buf then
                table.remove(listed_bufs, i)
                break
            end
        end

        if #listed_bufs < 1 then
            ---@type [string,string|integer?][]
            local chunks = { { "Cannot unload the last buffer" } }
            return false, chunks, false, {}
        end

        api.nvim_set_option_value("buflisted", false, { buf = buf })
        delete_opts.unload = true
    end

    if (not no_save) and api.nvim_get_option_value("modifiable", { buf = buf }) then
        api.nvim_buf_call(buf, function()
            api.nvim_cmd({ cmd = "update", mods = { silent = true } }, {})
        end)
    end

    local ok, err = pcall(api.nvim_buf_delete, buf, delete_opts) ---@type boolean, nil
    if ok then
        return true, nil, nil, nil
    end
    ---@type [string, string|integer?][]
    local chunks = { { err or ("Unknown error deleting buf " .. buf) } }
    return false, chunks, true, { err = true }
end

---@return Range4|nil
function M.get_vregionpos4()
    local mode = string.sub(api.nvim_get_mode().mode, 1, 1)
    if not (mode == "v" or mode == "V" or mode == "\22") then
        return nil
    end

    local cur = fn.getpos(".")
    local fin = fn.getpos("v")
    local selection = api.nvim_get_option_value("selection", { scope = "global" }) ---@type string
    local exclusive = selection == "exclusive"
    local region = fn.getregionpos(cur, fin, { type = mode, exclusive = exclusive })

    return { region[1][1][2], region[1][1][3], region[#region][2][2], region[#region][2][3] }
end
-- TODO: Replace with the nvim-tools implementation

-- LOW: Do this not with recursion to handle deep directories

---@param path string
---@param mode integer
---@return boolean, string?
function M.checked_mkdir_p(path, mode)
    vim.validate("path", path, "string")
    vim.validate("mode", mode, "number")

    local resolved_path = vim.fs.normalize(vim.fs.abspath(path))
    local stat, err, err_name = uv.fs_stat(resolved_path)
    if stat and stat.type == "directory" then
        return true, nil
    end

    if (not stat) and err_name ~= "ENOENT" then
        return false, err
    end

    if stat and stat.type ~= "directory" then
        return false, "Path exists, but is not a directory"
    end

    local parent = vim.fs.dirname(resolved_path) ---@type string|nil
    if not parent then
        return false, "Cannot resolve target parent"
    end

    local ok_p, err_p = M.checked_mkdir_p(parent, mode) ---@type boolean, string?
    if not ok_p then
        return false, err_p
    end

    local ok_m, err_m = uv.fs_mkdir(resolved_path, mode) ---@type boolean|nil, string|nil
    if ok_m then
        return true, nil
    end

    return false, err_m
end

return M
