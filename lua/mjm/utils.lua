-- From mini.jump2D. Extremely useful
-- local max_width = vim.o.columns * math.max(vim.o.cmdheight - 1, 0) + vim.v.echospace

local api = vim.api
local fn = vim.fn

---@class MjmUtils
local M = {}

--- @param prompt string
--- @return boolean, string
function M.get_input(prompt)
    local ok, result = pcall(fn.input, { prompt = prompt, cancelreturn = "" })

    if (not ok) and result == "Keyboard interrupt" then
        return true, ""
    else
        return ok, result
    end
end

--- @param cur_pos {[1]: integer, [2]: integer}
--- @param opts? {buf?: integer, set_pcmark?: boolean, win?: integer}
--- @return nil
function M.protected_set_cursor(cur_pos, opts)
    opts = opts or {}
    local buf = opts.buf or 0

    local line_count = api.nvim_buf_line_count(buf)
    cur_pos[1] = math.min(cur_pos[1], line_count)

    local row = cur_pos[1]
    local set_line = api.nvim_buf_get_lines(buf, row - 1, row, false)[1]
    cur_pos[2] = math.min(cur_pos[2], #set_line - 1)
    cur_pos[2] = math.max(cur_pos[2], 0)

    local win = opts.win or 0

    if opts.set_pcmark then
        local cur_row, cur_col = unpack(api.nvim_win_get_cursor(win))
        -- TODO: This does not actually update the jump list. But then, because this function
        -- is based on the idea that it can be fired remotely, just setting the PC mark from
        -- a normal command doesn't necessarily do what we want
        api.nvim_buf_set_mark(buf, "'", cur_row, cur_col, {})
    end

    api.nvim_win_set_cursor(win, cur_pos)
end

--- @class mjm.OpenBufSource
--- @field bufnr? integer
--- @field file? string

--- @class mjm.OpenBufOpts
--- @field buftype? string
--- @field clearjumps? boolean
--- @field cur_pos? {[1]: integer, [2]: integer}
--- @field force? boolean
--- @field open? "vsplit"|"split"|"tabnew"
--- @field win? integer
--- @field zz? boolean

--- @param source mjm.OpenBufSource
--- @param opts mjm.OpenBufOpts
--- @return boolean
--- Using bufload breaks BufReadPost autocmds and opt_local setup
--- nvim_set_current_buf will load the buf properly if it needs to
--- nvim_win_set_buf does the same, and also automatically moves the user into that window
function M.open_buf(source, opts)
    --- TODO: Scenario:
    --- - Create a new tab. It will contain a noname buffer
    --- - Use this to open a buf
    --- - The noname buffer will still be there
    --- - This does not happen when using :edit
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
        --- @diagnostic disable: missing-fields
        api.nvim_cmd({ cmd = "vsplit" }, {})
    elseif opts.open == "split" then
        api.nvim_cmd({ cmd = "split" }, {})
    elseif opts.open == "tabnew" then
        api.nvim_cmd({ cmd = "tabnew" }, {})
    end

    api.nvim_set_option_value("buflisted", true, { buf = buf })
    if opts.buftype then api.nvim_set_option_value("buftype", opts.buftype, { buf = buf }) end

    if opts.buftype == "help" then
        local win = opts.win or api.nvim_get_current_win()
        api.nvim_set_option_value("list", false, { win = win })
    end

    if cur_buf ~= buf then
        if opts.win then
            api.nvim_win_call(opts.win, function()
                api.nvim_set_current_buf(buf)
            end)
        else
            api.nvim_set_current_buf(buf)
        end
    end

    if opts.cur_pos then
        local win = opts.win or 0
        M.protected_set_cursor(opts.cur_pos, { buf = buf, set_pcmark = same_buf, win = win })
    end

    if opts.clearjumps then Cmd({ cmd = "clearjumps" }, {}) end
    if opts.zz then Cmd({ cmd = "normal", args = { "zz" }, bang = true }, {}) end

    Cmd({ cmd = "normal", args = { "zv" }, bang = true }, {})

    return true
end

---@param bufnr? integer
---@return boolean
function M.check_modifiable(bufnr)
    if api.nvim_get_option_value("modifiable", { buf = bufnr or 0 }) then
        return true
    else
        local err_msg = "E21: Cannot make changes, 'modifiable' is off" ---@type string
        api.nvim_echo({ { err_msg } }, true, { err = true })
        return false
    end
end

---@param line_num number -- One indexed
---@return integer|nil
M.get_indent = function(line_num)
    -- Captures nvim_treesitter#indent() if enabled
    if vim.bo.indentexpr == "" then
        local prevnonblank = fn.prevnonblank(line_num - 1) ---@type integer
        local prevnonblank_indent = fn.indent(prevnonblank) ---@type integer
        return prevnonblank_indent <= 0 and 0 or prevnonblank_indent
    end

    -- Most Nvim runtime indent expressions do not take an argument
    -- A few, however, take v:lnum
    -- v:lnum is not updated when nvim_exec2 is called, so it must be updated here
    -- A couple of the runtime expressions take '.' as an argument
    -- This is already updated before nvim_exec2 is called
    -- Other indentexpr arguments are not guaranteed to be handled properly
    vim.v.lnum = line_num
    local indentexpr_out = api.nvim_eval(vim.bo.indentexpr) --- @type any
    local indent = tonumber(indentexpr_out) ---@type number?
    return indent >= 0 and indent or nil
end

---@param buf number
---@param start_idx number
---@param end_idx number
---@return nil
local function fix_bookend_blanks(buf, start_idx, end_idx)
    local line = api.nvim_buf_get_lines(buf, start_idx, end_idx, true)[1] ---@type string
    local blank_line = (line == "") or line:match("^%s*$") ---@type any
    local last_line = api.nvim_buf_line_count(buf) == 1 ---@type boolean

    if last_line or not blank_line then return end

    api.nvim_buf_set_lines(buf, start_idx, end_idx, false, {})
    fix_bookend_blanks(buf, start_idx, end_idx)
end

M.fallback_formatter = function(buf)
    local shiftwidth = api.nvim_get_option_value("shiftwidth", { buf = buf }) ---@type any
    if shiftwidth == 0 then
        shiftwidth = api.nvim_get_option_value("tabstop", { buf = buf })
    else
        api.nvim_set_option_value("tabstop", shiftwidth, { buf = buf })
    end

    local expandtab = api.nvim_get_option_value("expandtab", { buf = buf }) ---@type any
    if expandtab then
        api.nvim_set_option_value("softtabstop", shiftwidth, { buf = buf })
        vim.cmd(buf .. "bufdo retab")
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
        if extra_spaces == 0 or not expandtab then return end

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

-- TODO: This should use vim.system and open the win in the callback

---@return nil
function M.check_word_under_cursor()
    local word = fn.expand("<cword>")
    if word == "" then
        vim.notify("No word under cursor", vim.log.levels.INFO)
        return
    end

    local cmd = "wn " .. fn.shellescape(word) .. " -over"
    local output = fn.system(cmd)
    if vim.v.shell_error == -1 then
        return vim.notify("Error running wn: " .. output, vim.log.levels.ERROR)
    end

    local lines = {}
    for line in output:gmatch("[^\n]+") do
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" then table.insert(lines, line) end
    end

    if #lines == 0 then
        return vim.notify("No results from WordNet for '" .. word .. "'", vim.log.levels.INFO)
    end

    vim.lsp.util.open_floating_preview(lines, "markdown", { border = Border })
end

function M.write_to_scratch_buf(lines)
    local scratch = api.nvim_create_buf(false, true)
    api.nvim_set_option_value("buftype", "nofile", { buf = scratch })
    api.nvim_set_option_value("bufhidden", "wipe", { buf = scratch })
    api.nvim_set_option_value("swapfile", false, { buf = scratch })

    api.nvim_buf_set_lines(scratch, 0, -1, false, vim.split(lines, "\n"))
    vim.cmd.vsplit()
    api.nvim_set_current_buf(scratch)
end

-- FUTURE: More sophisticated handling if we don't have a parser

function M.is_comment()
    local ok, lang_tree = pcall(vim.treesitter.get_parser)
    if (not ok) or not lang_tree then
        -- if type(lang_tree) == "string" then
        --     api.nvim_echo({ { lang_tree } }, true, { kind = "echoerr" })
        -- else
        --     vim.notify("Unknown error getting parser in is_comment", vim.log.levels.ERROR)
        -- end
        return false
    end
    lang_tree:parse()

    -- Include col before or a cursor at the very end of a comment will be a "chunk" node
    local row, col = unpack(api.nvim_win_get_cursor(0))
    local start_col = col > 0 and col - 1 or col
    local node = lang_tree:node_for_range({ row - 1, start_col, row - 1, col })
    if not node then return false end

    local comment_nodes = { "comment", "line_comment", "block_comment", "comment_content" }
    if vim.tbl_contains(comment_nodes, node:type()) then
        return true
    else
        return false
    end
end

-- Adapted from mike-jl/harpoonEx
-- # harpoon
--- @param opts {buf?: integer, bufname?: string}
--- @return nil
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

    if not full_bufname then return end

    local ok, harpoon = pcall(require, "harpoon")
    if (not ok) or not harpoon then
        api.nvim_echo({ { "Unable to require harpoon", "ErrorMsg" } }, true, { err = true })
    end

    local list = harpoon:list()
    if not list then return end

    local items = list.items
    local idx = nil

    for i, t in ipairs(items) do
        local item = fn.fnamemodify(t.value, ":p")
        if full_bufname == item then
            idx = i
            break
        end
    end

    if not idx then return end

    table.remove(list.items, idx)
    list._length = list._length - 1

    local extensions = require("harpoon.extensions")
    extensions.extensions:emit(extensions.event_names.REMOVE)
end

--- @param old_bufname string
--- @param new_bufname string
--- @return nil
--- # harpoon
function M.harpoon_mv_buf(old_bufname, new_bufname)
    local ok, harpoon = pcall(require, "harpoon")
    if (not ok) or not harpoon then
        api.nvim_echo({ { "Unable to require harpoon", "ErrorMsg" } }, true, { err = true })
    end

    local list = harpoon:list()
    if not list then return end

    local items = list.items
    if #items < 1 then return end

    local full_old_bufname = fn.fnamemodify(old_bufname, ":p")
    local idx = nil

    for i, t in ipairs(items) do
        local item = fn.fnamemodify(t.value, ":p")
        if item == full_old_bufname then
            idx = i
            break
        end
    end

    if not idx then return end

    local full_new_bufname = fn.fnamemodify(new_bufname, ":p")
    local relative_new_bufname = fn.fnamemodify(full_new_bufname, ":.")
    list.items[idx].value = relative_new_bufname

    local extensions = require("harpoon.extensions")
    extensions.extensions:emit(extensions.event_names.REMOVE)
end

---@param func function
---@return nil
function M.do_when_idle(func)
    vim.validate("fn", func, "callable")

    local idle_handle = vim.uv.new_idle() ---@type uv.uv_idle_t|nil
    if not idle_handle then
        func()
        return
    end

    idle_handle:start(function()
        vim.schedule(function()
            func()
        end)

        idle_handle:stop()
        idle_handle:close()
    end)
end

--- @param win integer
--- @param force boolean
--- @return integer
function M.pwin_close(win, force)
    vim.validate("win", win, "number")
    vim.validate("force", force, "boolean")
    if not api.nvim_win_is_valid(win) then return -1 end

    local tabpages = api.nvim_list_tabpages() --- @type integer[]
    local win_tabpage = api.nvim_win_get_tabpage(win) --- @type integer
    local win_tabpage_wins = api.nvim_tabpage_list_wins(win_tabpage) --- @type integer[]

    local buf = api.nvim_win_get_buf(win) --- @type integer
    if #tabpages == 1 and #win_tabpage_wins == 1 then return buf end

    local ok, _ = pcall(api.nvim_win_close, win, force) --- @type boolean, nil
    return ok and buf or -1
end

-- https://github.com/neovim/neovim/pull/33402
-- When nvim_buf_delete is run without the unload flag, it goes beyond
-- deleting the buffer into deleting shada state, including the '"' mark
-- TODO: Whenever nvim_buf_del is created, use that for deleting buffers

--- @param buf integer
--- @param force boolean
--- @param wipeout boolean
--- @return nil
function M.pbuf_rm(buf, force, wipeout)
    vim.validate("buf", buf, "number")
    vim.validate("force", force, "boolean")
    vim.validate("wipeout", wipeout, "boolean")
    if not api.nvim_buf_is_valid(buf) then return end

    local modifiable = GetOpt("modifiable", { buf = buf }) ---@type boolean
    if modifiable then
        api.nvim_buf_call(buf, function()
            Cmd({ cmd = "update", mods = { silent = true } }, {})
        end)
    end

    if not wipeout then SetOpt("buflisted", false, { buf = buf }) end
    local delete_opts = wipeout and { force = force } or { force = force, unload = true }
    pcall(api.nvim_buf_delete, buf, delete_opts)
end

--- @param win integer
--- @param force boolean
--- @param wipeout boolean
--- @return nil
function M.pclose_and_rm(win, force, wipeout)
    local buf = M.pwin_close(win, force)
    if buf > 0 then
        M.do_when_idle(function()
            if #fn.win_findbuf(buf) == 0 then M.pbuf_rm(buf, force, wipeout) end
        end)
    end
end

---@return Range4|nil
function M.get_vrange4()
    local mode = string.sub(api.nvim_get_mode().mode, 1, 1) ---@type string
    if not (mode == "v" or mode == "V" or mode == "\22") then return nil end

    local cur = fn.getpos(".") ---@type table
    local fin = fn.getpos("v") ---@type table
    local selection = api.nvim_get_option_value("selection", { scope = "global" }) ---@type string
    local exclusive = selection == "exclusive" ---@type boolean
    local region = fn.getregionpos(cur, fin, { type = mode, exclusive = exclusive }) ---@type table

    return { region[1][1][2], region[1][1][3], region[#region][2][2], region[#region][2][3] }
end

return M
