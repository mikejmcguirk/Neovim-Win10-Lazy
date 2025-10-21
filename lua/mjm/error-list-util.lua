---@class QfrUtil
local M = {}

local eo = Qfr_Defer_Require("mjm.error-list-open") ---@type QfrOpen
local et = Qfr_Defer_Require("mjm.error-list-tools") ---@type QfrTools
local ey = Qfr_Defer_Require("mjm.error-list-types") ---@type QfrTypes

local api = vim.api
local fn = vim.fn

-----------------
--- CMD UTILS ---
-----------------

---@param fargs string[]
---@return string|nil
function M._find_cmd_pattern(fargs)
    ey._validate_list(fargs, { type = "string" })

    for _, arg in ipairs(fargs) do
        if vim.startswith(arg, "/") then return string.sub(arg, 2) or "" end
    end

    return nil
end

---@param fargs string[]
---@param valid_args string[]
---@param default string
function M._check_cmd_arg(fargs, valid_args, default)
    ey._validate_list(fargs, { type = "string" })
    ey._validate_list(valid_args, { type = "string" })
    vim.validate("default", default, "string")

    for _, arg in ipairs(fargs) do
        if vim.tbl_contains(valid_args, arg) then return arg end
    end

    return default
end

-------------------
--- INPUT UTILS ---
-------------------

---@param input QfrInputType
---@return string
--- NOTE: This function assumes that an API input of "vimsmart" has already been resolved
function M._get_display_input_type(input)
    if input == "regex" then
        return "Regex"
    elseif input == "sensitive" then
        return "Case Sensitive"
    elseif input == "smartcase" then
        return "Smartcase"
    else
        return "Case Insensitive"
    end
end

-- TODO: get rid of the use_smartcase g:var
-- TODO: vimsmart should be renamed to something like usevim
-- Need to respect both ignorecase and smartcase
-- TODO: Conceptual problem: There are three sets of input types. The raw input type, which can
-- include respecting vim settings, the resolve input, which can include smartcase, and the
-- final input type, which cannot include smartcase (since we've checked the pattern). Should
-- probably distinguish the three types, since it prevents data sloppiness

---@param input QfrInputType
---@return QfrInputType
function M._resolve_input_type(input)
    ey._validate_input_type(input)

    if input ~= "vimsmart" then return input end

    local smartcase = M._get_g_var("qf_rancher_use_smartcase")
    if smartcase == true then
        return "smartcase"
    elseif smartcase == false then
        return "insensitive"
    end

    if api.nvim_get_option_value("smartcase", { scope = "global" }) then
        return "smartcase"
    else
        return "insensitive"
    end
end

---@param mode string
---@return string|nil
local function get_visual_pattern(mode)
    vim.validate("mode", mode, "string")
    vim.validate("mode", mode, function()
        return mode == "v" or mode == "V" or mode == "\22"
    end)

    local start_pos = fn.getpos(".") ---@type Range4
    local end_pos = fn.getpos("v") ---@type Range4
    local region = fn.getregion(start_pos, end_pos, { type = mode }) ---@type string[]

    if #region == 1 then
        local trimmed = region[1]:gsub("^%s*(.-)%s*$", "%1") ---@type string
        if #trimmed > 0 then return trimmed end
    elseif #region > 1 then
        for _, line in ipairs(region) do
            if line ~= "" then
                api.nvim_cmd({ cmd = "normal", args = { "\27" }, bang = true }, {})
                return table.concat(region, "\n")
            end
        end
    end

    api.nvim_echo({ { "get_visual_pattern: Empty selection", "" } }, false, {})
    return nil
end

---@param prompt string
---@return string|nil
local function get_input(prompt)
    vim.validate("prompt", prompt, "string")

    ---@type boolean, string
    local ok, pattern = pcall(fn.input, { prompt = prompt, cancelreturn = "" })
    if ok then return pattern end

    if pattern == "Keyboard interrupt" then return nil end

    local chunk = { (pattern or "Unknown error getting input"), "ErrorMsg" } ---@type string[]
    api.nvim_echo({ chunk }, true, { err = true })
    return nil
end

---@param prompt string
---@param input_pattern string|nil
---@param input_type QfrInputType
---@return string|nil
function M._resolve_pattern(prompt, input_pattern, input_type)
    vim.validate("prompt", prompt, "string")
    vim.validate("input_pattern", input_pattern, "string", true)
    ey._validate_input_type(input_type)

    if input_pattern then return input_pattern end

    local mode = string.sub(api.nvim_get_mode().mode, 1, 1) ---@type string
    local is_visual = mode == "v" or mode == "V" or mode == "\22" ---@type boolean
    if is_visual then return get_visual_pattern(mode) end

    local pattern = get_input(prompt) ---@type string|nil
    return (pattern and input_type == "insensitive") and string.lower(pattern) or pattern
end

------------------------
-- WRAPPING IDX FUNCS --
------------------------

---@param src_win integer|nil
---@param count integer
---@param wrapping_math function
---@return integer|nil
local function get_wrapping_idx(src_win, count, wrapping_math)
    ey._validate_win(src_win, true)
    ey._validate_uint(count)
    vim.validate("arithmetic", wrapping_math, "callable")

    local count1 = M._count_to_count1(count) ---@type integer|nil
    local size = et._get_list(src_win, { nr = 0, size = 0 }).size ---@type integer
    if size < 1 then return nil end

    local cur_idx = et._get_list(src_win, { nr = 0, idx = 0 }).idx ---@type integer
    if cur_idx < 1 then return nil end

    return wrapping_math(cur_idx, count1, 1, size)
end

---@param src_win integer|nil
---@param count integer
---@return integer|nil
function M._get_idx_wrapping_sub(src_win, count)
    return get_wrapping_idx(src_win, count, M._wrapping_sub)
end

---@param src_win integer|nil
---@param count integer
---@return integer|nil
function M._get_idx_wrapping_add(src_win, count)
    return get_wrapping_idx(src_win, count, M._wrapping_add)
end

---------------------------
-- LIST IDX GETTER FUNCS --
---------------------------

-- LOW: An obvious expansion of this concept would be to also pass in a specific list

---@param src_win integer|nil
---@param idx integer
---@return vim.quickfix.entry|nil, integer|nil
local function get_item(src_win, idx)
    ey._validate_win(src_win, true)
    ey._validate_uint(idx)

    ---@type vim.quickfix.entry[]
    local items = et._get_list(src_win, { nr = 0, idx = idx, items = true }).items
    if #items < 1 then return nil, nil end

    local item = items[1] ---@type vim.quickfix.entry
    if item.bufnr and api.nvim_buf_is_valid(item.bufnr) then return item, idx end

    api.nvim_echo({ { "List item bufnr is invalid", "ErrorMsg" } }, true, { err = true })
    return nil, nil
end

---@type QfRancherIdxFunc
function M._get_item_under_cursor(src_win)
    return get_item(src_win, fn.line("."))
end

---@type QfRancherIdxFunc
function M._get_item_wrapping_sub(src_win)
    local idx = M._get_idx_wrapping_sub(src_win, vim.v.count)
    if not idx then return nil, nil end
    return get_item(src_win, idx)
end

---@type QfRancherIdxFunc
function M._get_item_wrapping_add(src_win)
    local idx = M._get_idx_wrapping_add(src_win, vim.v.count)
    if not idx then return nil, nil end
    return get_item(src_win, idx)
end

----------
-- MISC --
----------

-- TODO: This needs another breakup

---@param win integer
---@param todo function
---@return any
function M._locwin_check(win, todo)
    ey._validate_win(win, false)

    local qf_id = fn.getloclist(win, { id = 0 }).id ---@type integer
    if qf_id == 0 then
        api.nvim_echo({ { "Current window has no location list", "" } }, false, {})
        return
    end

    return todo()
end

---@param count integer
---@return integer
function M._count_to_count1(count)
    ey._validate_uint(count)
    return math.max(count, 1)
end

---@param x integer
---@param y integer
---@param min integer
---@param max integer
---@return integer
function M._wrapping_add(x, y, min, max)
    local period = max - min + 1 ---@type integer
    return ((x - min + y) % period) + min
end

---@param x integer
---@param y integer
---@param min integer
---@param max integer
---@return integer
function M._wrapping_sub(x, y, min, max)
    local period = max - min + 1 ---@type integer
    return ((x - y - min) % period) + min
end

---@param win integer
---@return boolean
function M._valid_win_for_loclist(win)
    ey._validate_win(win, true)
    if not win then return false end

    local wintype = fn.win_gettype(win)
    if wintype == "" or wintype == "loclist" then return true end

    ---@type string
    local text = "Window " .. win .. " with type " .. wintype .. " cannot contain a location list"
    api.nvim_echo({ { text, "ErrorMsg" } }, true, { err = true })
    return false
end

---@param msg string
---@param print_msgs boolean
---@param is_err boolean
---@return nil
function M._checked_echo(msg, print_msgs, is_err)
    if not print_msgs then return end

    if is_err then
        api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
    else
        api.nvim_echo({ { msg, "" } }, false, {})
    end
end

-- TODO: This doesn't work if you're dealing with the last window but want to rm the last buf

---@param win integer
---@param force boolean
---@return integer
function M._pwin_close(win, force)
    ey._validate_uint(win)
    vim.validate("force", force, "boolean")

    if not api.nvim_win_is_valid(win) then return -1 end

    local tabpages = api.nvim_list_tabpages() ---@type integer[]
    local win_tabpage = api.nvim_win_get_tabpage(win) ---@type integer
    local win_tabpage_wins = api.nvim_tabpage_list_wins(win_tabpage) ---@type integer[]
    if #tabpages == 1 and #win_tabpage_wins == 1 then return -1 end

    local buf = api.nvim_win_get_buf(win) ---@type integer
    local ok, _ = pcall(api.nvim_win_close, win, force) ---@type boolean, nil
    return ok and buf or -1
end

---@param win integer
---@param cur_pos {[1]: integer, [2]: integer}
---@return nil
function M._protected_set_cursor(win, cur_pos)
    ey._validate_win(win)
    ey._validate_cur_pos(cur_pos)

    local adj_cur_pos = vim.deepcopy(cur_pos, true) ---@type {[1]: integer, [2]: integer}
    local win_buf = api.nvim_win_get_buf(win) ---@type integer

    local line_count = api.nvim_buf_line_count(win_buf) ---@type integer
    adj_cur_pos[1] = math.min(adj_cur_pos[1], line_count)

    local row = adj_cur_pos[1] ---@type integer
    local set_line = api.nvim_buf_get_lines(win_buf, row - 1, row, false)[1] ---@type string
    adj_cur_pos[2] = math.min(adj_cur_pos[2], #set_line - 1)
    adj_cur_pos[2] = math.max(adj_cur_pos[2], 0)

    api.nvim_win_set_cursor(win, adj_cur_pos)
end

-- TODO: https://github.com/neovim/neovim/pull/33402
-- Redo this once this issue is resolved

---@param buf integer
---@param force boolean
---@param wipeout boolean
---@return nil
function M._pbuf_rm(buf, force, wipeout)
    ey._validate_uint(buf)
    vim.validate("force", force, "boolean")
    vim.validate("wipeout", wipeout, "boolean")

    if not api.nvim_buf_is_valid(buf) then return end

    if not wipeout then api.nvim_set_option_value("buflisted", false, { buf = buf }) end

    local delete_opts = wipeout and { force = force } or { force = force, unload = true }
    pcall(api.nvim_buf_delete, buf, delete_opts)
end

---@param win integer
---@param force boolean
---@param wipeout boolean
---@return nil
function M._pclose_and_rm(win, force, wipeout)
    local buf = M._pwin_close(win, force)
    if buf > 0 then
        -- MAYBE: Do when idle
        vim.schedule(function()
            if #fn.win_findbuf(buf) == 0 then M._pbuf_rm(buf, force, wipeout) end
        end)
    end
end

-- PR: Why can't this be a part of Nvim core?
-- MID: This could be a binary search instead

---@param vcol integer
---@param line string
---@return boolean, integer, integer
function M._vcol_to_byte_bounds(vcol, line)
    ey._validate_uint(vcol)
    vim.validate("line", line, "string")

    if vcol == 0 or #line <= 1 then return true, 0, 0 end

    local max_vcol = fn.strdisplaywidth(line) ---@type integer
    if vcol > max_vcol then return false, 0, 0 end

    local charlen = fn.strcharlen(line) ---@type integer
    for char_idx = 0, charlen - 1 do
        local start_byte = fn.byteidx(line, char_idx) ---@type integer
        if start_byte == -1 then return false, 0, 0 end

        local char = fn.strcharpart(line, char_idx, 1, true) ---@type string
        local fin_byte = start_byte + #char - 1 ---@type integer

        local test_str = line:sub(1, fin_byte + 1) ---@type string
        local test_vcol = fn.strdisplaywidth(test_str) ---@type integer
        if test_vcol >= vcol then return true, start_byte, fin_byte end
    end

    return false, 0, 0
end

---@param vcol integer
---@param line string
---@return integer
function M._vcol_to_end_col_(vcol, line)
    ey._validate_uint(vcol) ---@type QfrTypes
    vim.validate("line", line, "string")

    local ok, _, fin_byte = M._vcol_to_byte_bounds(vcol, line) ---@type boolean, integer
    if ok then
        return math.min(fin_byte + 1, #line)
    else
        return #line
    end
end

-- NOTE: Handle all validation here with built-ins to avoid looping code
-- TODO: The table validation really should be done during initialization, and since it refers
-- to a static, non-advertised constant, should be gated behind a g_var

---@param g_var string
---@param allow_nil? boolean
---@return any
function M._get_g_var(g_var, allow_nil)
    vim.validate("g_var", g_var, "string")
    vim.validate("allow_nil", allow_nil, "boolean", true)

    local g_var_data = _QFR_G_VAR_MAP[g_var] ---@type {[1]:string[], [2]:any}

    vim.validate("g_var_data", g_var_data, function()
        return #g_var_data == 2
    end, "G var table info should containt two elements")

    vim.validate("g_var_data[1]", g_var_data[1], function()
        for _, value in pairs(g_var_data[1]) do
            if type(value) ~= "string" then return false end
        end

        return true
    end, "G var table info should containt two elements")

    vim.validate("g_var_data[2]", g_var_data[2], function()
        return type(g_var_data[2]) ~= "nil"
    end, "G var defaults canot be nil")

    local cur_g_val = vim.g[g_var] ---@type any
    if allow_nil and type(cur_g_val) == "nil" then return nil end

    if vim.tbl_contains(g_var_data[1], type(cur_g_val)) then
        return cur_g_val
    else
        return g_var_data[2]
    end
end

---@param item_lnum integer
---@param item_col integer
---@return {[1]:integer, [2]:integer}
function M._qf_pos_to_cur_pos(item_lnum, item_col)
    local row = math.max(item_lnum, 1) ---@type integer
    local col = item_col - 1 ---@type integer
    col = math.max(col, 0)

    return { row, col }
end

-- TODO: Put this in preview module
-- TODO: By centralizing all zzze here, you can add a skip_zzze g_var for users who don't like
-- that behavior

---@param win integer
---@return nil
function M._do_zzze(win)
    ey._validate_win(win)

    api.nvim_win_call(win, function()
        api.nvim_cmd({ cmd = "normal", args = { "zz" }, bang = true }, {})
        api.nvim_cmd({ cmd = "normal", args = { "ze" }, bang = true }, {})
    end)
end

---@param item vim.quickfix.entry
---@param opts QfRancherBufOpenOpts
---@return boolean
function M._open_item_to_win(item, opts)
    ey._validate_list_item(item)
    ey._validate_open_buf_opts(opts)

    local buf = item.bufnr ---@type integer|nil
    if not (buf and api.nvim_buf_is_valid(buf)) then return false end

    local win = opts.win or api.nvim_get_current_win() ---@type integer
    if not api.nvim_win_is_valid(win) then return false end

    local already_open = api.nvim_win_get_buf(win) == buf ---@type boolean
    api.nvim_set_option_value("buflisted", true, { buf = buf })
    if opts.buftype == "help" then
        api.nvim_set_option_value("buftype", opts.buftype, { buf = buf })
    end

    -- TODO: Implement prepare_help_buffer
    if not already_open then
        api.nvim_win_call(win, function()
            -- NOTE: This loads the buf if necessary. Do not use bufload
            api.nvim_set_current_buf(buf)
        end)
    end

    if opts.clearjumps then
        api.nvim_win_call(win, function()
            api.nvim_cmd({ cmd = "clearjumps" }, {})
        end)
    end

    if not opts.skip_set_cur_pos then
        if already_open then
            vim.api.nvim_buf_call(buf, function()
                api.nvim_cmd({ cmd = "normal", args = { "m'" }, bang = true }, {})
            end)
        end

        ---@type {[1]:integer, [2]:integer}
        local cur_pos = M._qf_pos_to_cur_pos(item.lnum, item.col)
        M._protected_set_cursor(win, cur_pos)
    end

    if not opts.skip_zzze then M._do_zzze(win) end
    api.nvim_win_call(win, function()
        api.nvim_cmd({ cmd = "normal", args = { "zv" }, bang = true }, {})
    end)

    if opts.goto_win then vim.api.nvim_set_current_win(win) end

    return true
end

---@param src_win integer|nil
---@param list_nr integer|"$"
---@return integer
function M._clear_list_and_resize(src_win, list_nr)
    ey._validate_win(src_win, true)

    local result = et._clear_list(src_win, list_nr)

    if result == -1 then return result end
    if not M._get_g_var("qf_rancher_auto_resize_changes") then return result end

    if result == 0 or result == et._get_list(src_win, { nr = 0 }).nr then
        local tabpage = src_win and api.nvim_win_get_tabpage(src_win)
            or api.nvim_get_current_tabpage()
        eo._resize_lists_by_win(src_win, { tabpage = tabpage })
    end

    return result
end

----------------------
--- WINDOW FINDING ---
----------------------

---@param opts QfRancherTabpageOpts
---@return integer[]
function M._resolve_tabpages(opts)
    ey._validate_tabpage_opts(opts)

    if opts.all_tabpages then
        return api.nvim_list_tabpages()
    elseif opts.tabpages then
        return opts.tabpages
    elseif opts.tabpage then
        return { opts.tabpage }
    else
        return { api.nvim_get_current_tabpage() }
    end
end

-- NOTE: Used in hot loops. No validations here
-- NOTE: Use wintype because we need to be able to accurately check orphan loclist wins with a
-- qf_id or 0

---@param qf_id integer
---@param win integer
---@return boolean
local function is_loclist_win(qf_id, win)
    local tw_qf_id = fn.getloclist(win, { id = 0 }).id ---@type integer
    if tw_qf_id ~= qf_id then return false end
    local wintype = fn.win_gettype(win)
    if wintype == "loclist" then
        return true
    else
        return false
    end
end

--- If searching for wins by qf_id, passing a zero id is allowed so that orphans can be checked

---@param win integer
---@param opts QfRancherTabpageOpts
---@return integer|nil
function M._get_loclist_win_by_win(win, opts)
    ey._validate_win(win, false)

    local qf_id = fn.getloclist(win, { id = 0 }).id ---@type integer
    if qf_id == 0 then
        return nil
    else
        return M._get_loclist_win_by_qf_id(qf_id, opts)
    end
end

---@param qf_id integer
---@param opts QfRancherTabpageOpts
---@return integer|nil
function M._get_loclist_win_by_qf_id(qf_id, opts)
    ey._validate_uint(qf_id)
    ey._validate_tabpage_opts(opts)

    local tabpages = M._resolve_tabpages(opts) ---@type integer[]
    for _, tabpage in ipairs(tabpages) do
        local tabpage_wins = api.nvim_tabpage_list_wins(tabpage) ---@type integer[]
        for _, t_win in ipairs(tabpage_wins) do
            if is_loclist_win(qf_id, t_win) then return t_win end
        end
    end

    return nil
end

---@param win integer
---@param opts QfRancherTabpageOpts
---@return integer[]
function M._get_loclist_wins_by_win(win, opts)
    ey._validate_win(win, false)

    local qf_id = fn.getloclist(win, { id = 0 }).id ---@type integer
    if qf_id == 0 then return {} end

    return M._get_ll_wins_by_qf_id(qf_id, opts)
end

---@param qf_id integer
---@param opts QfRancherTabpageOpts
---@return integer[]
function M._get_ll_wins_by_qf_id(qf_id, opts)
    ey._validate_uint(qf_id)
    ey._validate_tabpage_opts(opts)

    local wins = {} ---@type integer[]
    local tabpages = M._resolve_tabpages(opts) ---@type integer[]
    for _, tabpage in ipairs(tabpages) do
        local tabpage_wins = api.nvim_tabpage_list_wins(tabpage) ---@type integer[]
        for _, t_win in ipairs(tabpage_wins) do
            if is_loclist_win(qf_id, t_win) then table.insert(wins, t_win) end
        end
    end

    return wins
end

---@param opts QfRancherTabpageOpts
---@return integer[]
function M._get_all_loclist_wins(opts)
    local ll_wins = {} ---@type integer[]
    local tabpages = M._resolve_tabpages(opts) ---@type integer[]

    for _, tabpage in ipairs(tabpages) do
        local tabpage_wins = api.nvim_tabpage_list_wins(tabpage) ---@type integer[]
        for _, win in ipairs(tabpage_wins) do
            local wintype = fn.win_gettype(win)
            if wintype == "loclist" then table.insert(ll_wins, win) end
        end
    end

    return ll_wins
end

---@param opts QfRancherTabpageOpts
---@return integer[]
function M._get_qf_wins(opts)
    local wins = {} ---@type integer[]
    local tabpages = M._resolve_tabpages(opts) ---@type integer[]

    for _, tabpage in ipairs(tabpages) do
        local tabpage_wins = api.nvim_tabpage_list_wins(tabpage) ---@type integer[]
        for _, t_win in ipairs(tabpage_wins) do
            local wintype = fn.win_gettype(t_win)
            if wintype == "quickfix" then table.insert(wins, t_win) end
        end
    end

    return wins
end

---@param opts QfRancherTabpageOpts
---@return integer|nil
function M._get_qf_win(opts)
    local tabpages = M._resolve_tabpages(opts) ---@type integer[]

    for _, tabpage in ipairs(tabpages) do
        local tabpage_wins = api.nvim_tabpage_list_wins(tabpage) ---@type integer[]
        for _, t_win in ipairs(tabpage_wins) do
            local wintype = fn.win_gettype(t_win)
            if wintype == "quickfix" then return t_win end
        end
    end

    return nil
end

---@param list_win integer
---@param opts QfRancherTabpageOpts
---@return integer|nil
function M._find_loclist_origin(list_win, opts)
    ey._validate_list_win(list_win)

    local qf_id = fn.getloclist(list_win, { id = 0 }).id ---@type integer
    if qf_id == 0 then return nil end

    local tabpages = M._resolve_tabpages(opts) ---@type integer[]
    for _, tabpage in ipairs(tabpages) do
        local tabpage_wins = api.nvim_tabpage_list_wins(tabpage) ---@type integer[]
        for _, win in ipairs(tabpage_wins) do
            local win_qf_id = fn.getloclist(win, { id = 0 }).id ---@type integer
            local win_wintype = fn.win_gettype(win)
            if win_qf_id == qf_id and win_wintype == "" then return win end
        end
    end

    return nil
end

return M

------------
--- TODO ---
------------

--- Tests
--- Docs
