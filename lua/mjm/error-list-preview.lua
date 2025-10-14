---------------
--- CREDITS ---
---------------

--- https://github.com/r0nsha/qfpreview.nvim

local M = {}

-------------------
--- MODULE DATA ---
-------------------

local hl_ns = vim.api.nvim_create_namespace("qf-rancher-preview-hl") --- @type integer

-- DOCUMENT: This highlight group
local hl_name = "QfRancherHighlightItem" --- @type string
local cur_hl = vim.api.nvim_get_hl(0, { name = hl_name }) --- @type vim.api.keyset.get_hl_info
if (not cur_hl) or #vim.tbl_keys(cur_hl) == 0 then
    -- DOCUMENT: That this links to CurSearch by default
    vim.api.nvim_set_hl(0, hl_name, { link = "CurSearch" })
end

--- @class QfRancherPreviewState
--- @field preview_win integer|nil
--- @field list_win integer|nil

local preview_state = {
    preview_win = nil,
    list_win = nil,
} --- @type QfRancherPreviewState

--- @param self QfRancherPreviewState
--- @param list_win integer
--- @param preview_win integer
--- @return nil
function preview_state:set(list_win, preview_win)
    local ey = require("mjm.error-list-types")
    ey._validate_list_win(list_win)
    ey._validate_win(preview_win)

    self.list_win = list_win
    self.preview_win = preview_win
end

--- @param list_win integer
--- @param preview_win integer
--- @return boolean
local function is_preview_open(list_win, preview_win)
    return type(list_win) == "number" and type(preview_win) == "number"
end

--- @param list_win integer
--- @param preview_win integer
--- @return boolean
local function is_preview_closed(list_win, preview_win)
    return type(list_win) == "nil" and type(preview_win) == "nil"
end

--- @param list_win integer
--- @param preview_win integer
--- @return nil
local function validate_state(list_win, preview_win)
    local ey = require("mjm.error-list-types")
    ey._validate_list_win(list_win, true)
    ey._validate_win(list_win, true)
    assert(is_preview_open(list_win, preview_win) or is_preview_closed(list_win, preview_win))
end

--- @param self QfRancherPreviewState
--- @return boolean
function preview_state:is_open()
    validate_state(self.list_win, self.preview_win)
    return is_preview_open(self.list_win, self.preview_win)
end

--- @param self QfRancherPreviewState
--- @return nil
function preview_state:clear()
    self.preview_win = nil
    self.list_win = nil
end

--- @param self QfRancherPreviewState
--- @return boolean
function preview_state:is_cur_list_win(win)
    validate_state(self.list_win, self.preview_win)
    return win == self.list_win
end

local bufs = {} --- @type integer[]
local extmarks = {} --- @type integer[]

local group_name = "qf-rancher-preview-group" --- @type string
local group = vim.api.nvim_create_augroup(group_name, {}) --- @type integer

local SCROLLOFF = 6

--- @return nil
local function close_and_clear()
    if preview_state:is_open() then
        require("mjm.error-list-util")._pwin_close(preview_state.preview_win, true)
        preview_state:clear()
    end
end

--- @return nil
local function clear_session_data()
    close_and_clear()

    for _, buf in pairs(bufs) do
        require("mjm.error-list-util")._pbuf_rm(buf, true, true)
    end

    bufs = {}
    extmarks = {}

    --- @type vim.api.keyset.get_autocmds.ret[]
    local autocmds = vim.api.nvim_get_autocmds({ group = group })
    for _, a in pairs(autocmds) do
        vim.api.nvim_del_autocmd(a.id)
    end
end

--- @return boolean
local function has_no_list_wins()
    local eu = require("mjm.error-list-util") --- @type QfRancherUtils
    local qf_wins = eu._get_qf_wins({ all_tabpages = true }) --- @type integer[]
    local ll_wins = eu._get_all_loclist_wins({ all_tabpages = true }) --- @type integer[]

    return #qf_wins == 0 and #ll_wins == 0
end

--- @return nil
local function create_autocmds()
    if #vim.api.nvim_get_autocmds({ group = group }) > 0 then
        return
    end

    vim.api.nvim_create_autocmd("CursorMoved", {
        group = group,
        callback = function()
            if preview_state:is_cur_list_win(vim.api.nvim_get_current_win()) then
                M._update_preview_win_buf()
            end
        end,
    })

    vim.api.nvim_create_autocmd("BufEnter", {
        group = group,
        callback = function()
            if has_no_list_wins() then
                clear_session_data()
            end
        end,
    })

    vim.api.nvim_create_autocmd("WinClosed", {
        group = group,
        callback = function()
            -- Schedule so that the closed win is removed from the window layout
            -- TEST: Needs a test to verify this assumption holds
            vim.schedule(function()
                if has_no_list_wins() then
                    clear_session_data()
                end
            end)
        end,
    })

    vim.api.nvim_create_autocmd("WinEnter", {
        group = group,
        callback = function()
            if not preview_state:is_cur_list_win(vim.api.nvim_get_current_win()) then
                M._close_preview_win()
            end
        end,
    })

    vim.api.nvim_create_autocmd("WinLeave", {
        group = group,
        callback = function()
            if preview_state:is_cur_list_win(vim.api.nvim_get_current_win()) then
                M._close_preview_win()
            end
        end,
    })

    vim.api.nvim_create_autocmd("WinResized", {
        group = group,
        callback = function()
            M._update_preview_win_pos()
        end,
    })
end

--------------------
--- WINDOW SETUP ---
--------------------

--- @return QfRancherBorder
local function get_border()
    local g_border = vim.g.qf_rancher_preview_border --- @type QfRancherBorder
    if g_border then
        require("mjm.error-list-types")._validate_border(g_border)
        return g_border
    else
        local winborder = vim.api.nvim_get_option_value("winborder", { scope = "global" })
        return winborder ~= "" and winborder or "single"
    end
end

--- @param buf integer
--- @return nil
local function set_preview_win_title(buf)
    assert(preview_state:is_open())
    local g_show_title = vim.g.qf_rancher_preview_show_title --- @type boolean|nil
    vim.validate("g_show_title", g_show_title, "boolean", true)
    local g_title_pos = vim.g.qf_rancher_preview_title_pos --- @type string|nil
    if g_title_pos then
        require("mjm.error-list-types")._validate_title_pos(g_title_pos)
    end

    if not g_show_title then
        vim.api.nvim_win_set_config(preview_state.preview_win, {
            title = nil,
        })

        return
    end

    local preview_name = vim.api.nvim_buf_get_name(buf) --- @type string
    local relative_name = vim.fn.fnamemodify(preview_name, ":.")
    local title_pos = g_title_pos and g_title_pos or "left"
    vim.api.nvim_win_set_config(preview_state.preview_win, {
        title = relative_name,
        title_pos = title_pos,
    })
end

--- @param base_cfg table
--- @param e_lines integer
--- @param e_cols integer
--- @param padding integer
--- @param preview_border_width integer
--- @return table
local function get_fallback_win_config(base_cfg, e_lines, e_cols, padding, preview_border_width)
    local fallback_base = vim.tbl_extend("force", base_cfg, {
        relative = "tabline",
        height = math.floor(e_lines * 0.4),
        width = e_cols - (padding * 2) - preview_border_width,
        col = 1,
    }) --- @type vim.api.keyset.win_config

    local screenrow = vim.fn.screenrow() --- @type integer
    local half_way = e_lines * 0.5 --- @type number
    if screenrow <= half_way then
        return vim.tbl_extend("force", fallback_base, { row = math.floor(e_lines * 0.6) })
    else
        return vim.tbl_extend("force", fallback_base, { row = 0 })
    end
end

--- @param list_win integer
--- @return vim.api.keyset.win_config
local function get_win_cfg(list_win)
    require("mjm.error-list-types")._validate_list_win(list_win)

    local qf_pos = vim.api.nvim_win_get_position(list_win) --- @type [integer, integer]
    local qf_height = vim.api.nvim_win_get_height(list_win) --- @type integer
    local qf_width = vim.api.nvim_win_get_width(list_win) --- @type integer
    local e_lines = vim.api.nvim_get_option_value("lines", { scope = "global" }) --- @type integer
    local e_cols = vim.api.nvim_get_option_value("columns", { scope = "global" }) --- @type integer

    local border = get_border() --- @type string|string[]
    local preview_border_width = border ~= "none" and 2 or 0 --- @type integer
    local vim_border = 1 --- @type integer
    local padding = 1 --- @type integer

    -- Window width and height only account for the inside of the window, not its borders. For
    -- consistency, track the target internal size of the window separately from the space needed
    -- to render the window plus the borders and padding
    local MIN_WIDTH = 79 --- @type integer
    local MIN_HEIGHT = 6 --- @type integer
    local MAX_HEIGHT = 24 --- @type integer

    local min_x_space = MIN_WIDTH + (padding * 2) + preview_border_width --- @type integer
    local min_y_space = MIN_HEIGHT + preview_border_width --- @type integer

    local base_cfg = { border = border, focusable = false } --- @type vim.api.keyset.win_config
    --- @type vim.api.keyset.win_config
    local win_cfg = vim.tbl_extend("force", base_cfg, { relative = "win", win = list_win })

    local avail_y_above = math.max(qf_pos[1] - vim_border - 1, 0) --- @type integer
    local avail_y_below = e_lines - (qf_pos[1] + qf_height + vim_border + 1) --- @type integer
    -- If space is available to the left or right, the vim border has to be there
    local avail_x_left = math.max(qf_pos[2] - vim_border, 0) --- @type integer
    --- @type integer
    local avail_x_right = math.max(e_cols - (qf_pos[2] + qf_width + vim_border), 0)
    local avail_width = qf_width - (padding * 2) - preview_border_width --- @type integer
    local avail_e_width = e_cols - (padding * 2) - preview_border_width --- @type integer

    --- @param height integer
    --- @param row integer
    --- @return vim.api.keyset.win_config
    local function cfg_vert_spill(height, row)
        local x_diff = min_x_space - qf_width --- @type integer
        local half_diff = math.ceil(x_diff * 0.5) --- @type integer
        local r_shift = math.max(half_diff - avail_x_left, 0) --- @type integer
        local l_shift = math.max(half_diff - avail_x_right, 0) --- @type integer
        return vim.tbl_extend("force", win_cfg, {
            height = height,
            row = row,
            width = math.min(MIN_WIDTH, avail_e_width),
            col = (half_diff * -1) + r_shift - l_shift + 1,
        })
    end

    -- Design note: Prefer rendering previews with spill into other wins to keep the direction
    -- they appear as consistent as possible
    if avail_y_above >= min_y_space then
        local height = avail_y_above - preview_border_width --- @type integer
        height = math.min(height, MAX_HEIGHT) --- @type integer
        local row = (height + preview_border_width + vim_border) * -1 --- @type integer
        if qf_width >= min_x_space then
            return vim.tbl_extend("force", win_cfg, {
                height = height,
                row = row,
                width = avail_width,
                col = 1,
            })
        else
            return cfg_vert_spill(height, row)
        end
    end

    if avail_y_below >= min_y_space then
        local height = avail_y_below - preview_border_width --- @type integer
        height = math.min(height, MAX_HEIGHT) --- @type integer
        local row = qf_height + vim_border --- @type integer
        if qf_width >= min_x_space then
            return vim.tbl_extend("force", win_cfg, {
                height = height,
                row = row,
                width = avail_width,
                col = 1,
            })
        else
            return cfg_vert_spill(height, row)
        end
    end

    local avail_height = qf_height - (padding * 2) - preview_border_width --- @type integer
    local avail_e_lines = e_lines - preview_border_width --- @type integer
    local side_height = math.min(avail_height, MAX_HEIGHT) --- @type integer
    local function cfg_hor_spill(width, col)
        local y_diff = min_y_space - qf_height --- @type integer
        local half_diff = math.floor(y_diff * 0.5) --- @type integer
        local u_shift = math.max(half_diff - avail_y_above, 0) --- @type integer
        local d_shift = math.max(half_diff - avail_y_below, 0) --- @type integer
        return vim.tbl_extend("force", win_cfg, {
            height = math.min(MIN_HEIGHT, avail_e_lines),
            row = (half_diff * -1) - u_shift + d_shift - 1,
            width = width,
            col = col,
        })
    end

    local function open_left()
        local col = (qf_pos[2] - vim_border) * -1 --- @type integer
        local width = avail_x_left - (padding * 2) - preview_border_width --- @type integer
        if qf_height >= min_y_space then
            return vim.tbl_extend("force", win_cfg, {
                height = side_height,
                row = 0,
                width = width,
                col = col,
            })
        else
            return cfg_hor_spill(width, col)
        end
    end

    local function open_right()
        local col = qf_pos[2] + qf_width + vim_border + padding --- @type integer
        local width = avail_x_right - (padding * 2) - preview_border_width --- @type integer
        if qf_height >= min_y_space then
            return vim.tbl_extend("force", win_cfg, {
                height = side_height,
                row = 0,
                width = width,
                col = col,
            })
        else
            return cfg_hor_spill(width, col)
        end
    end

    if vim.api.nvim_get_option_value("splitright", { scope = "global" }) then
        if avail_x_right >= min_x_space then
            return open_right()
        elseif avail_x_left >= min_x_space then
            return open_left()
        end
    else
        if avail_x_left >= min_x_space then
            return open_left()
        elseif avail_x_right >= min_x_space then
            return open_right()
        end
    end

    return get_fallback_win_config(base_cfg, e_lines, e_cols, padding, preview_border_width)
end

--- @param win_cfg vim.api.keyset.win_config
--- @param preview_buf integer
--- @return integer
local function create_preview_win(win_cfg, preview_buf)
    vim.validate("win_cfg", win_cfg, "table")
    require("mjm.error-list-types")._validate_buf(preview_buf)

    local g_winblend = vim.g.qf_rancher_preview_winblend --- @type number|nil
    if g_winblend then
        require("mjm.error-list-types")._validate_winblend(g_winblend)
    end

    local preview_win = vim.api.nvim_open_win(preview_buf, false, win_cfg) --- @type integer

    vim.api.nvim_set_option_value("cc", "", { win = preview_win })
    vim.api.nvim_set_option_value("cul", true, { win = preview_win })

    vim.api.nvim_set_option_value("fdc", "0", { win = preview_win })
    vim.api.nvim_set_option_value("fdm", "manual", { win = preview_win })

    vim.api.nvim_set_option_value("list", false, { win = preview_win })

    vim.api.nvim_set_option_value("nu", true, { win = preview_win })
    vim.api.nvim_set_option_value("rnu", false, { win = preview_win })
    vim.api.nvim_set_option_value("scl", "no", { win = preview_win })

    vim.api.nvim_set_option_value("spell", false, { win = preview_win })

    local winblend = g_winblend and g_winblend or 0 --- @type integer
    vim.api.nvim_set_option_value("winblend", winblend, { win = preview_win })

    vim.api.nvim_set_option_value("so", SCROLLOFF, { win = preview_win })
    vim.api.nvim_set_option_value("siso", SCROLLOFF, { win = preview_win })

    return preview_win
end

-----------------
--- BUF SETUP ---
-----------------

--- @param preview_buf integer
--- @param item table
--- @return Range4
local function range_qf_to_zero_(preview_buf, item)
    local ey = require("mjm.error-list-types")
    ey._validate_buf(preview_buf)
    ey._validate_list_item(item)

    local eu = require("mjm.error-list-util")
    local row = item.lnum > 0 and item.lnum - 1 or 0 --- @type integer
    row = math.min(row, vim.api.nvim_buf_line_count(preview_buf) - 1)

    --- @type string
    local start_line = vim.api.nvim_buf_get_lines(preview_buf, row, row + 1, false)[1]
    local col = (function()
        if item.col <= 0 then
            return 0
        end

        if item.vcol == 1 then
            --- @type boolean, integer, integer
            local _, start_byte, _ = eu._vcol_to_byte_bounds(item.col, start_line)
            return start_byte
        else
            return math.min(item.col - 1, #start_line - 1)
        end
    end)() --- @type integer

    local fin_row = item.end_lnum > 0 and item.end_lnum - 1 or row --- @type integer
    fin_row = math.max(fin_row, row)

    --- @type string
    local fin_line = fin_row == row and start_line
        or vim.api.nvim_buf_get_lines(preview_buf, fin_row, fin_row + 1, false)[1]
    local fin_col_ = (function()
        if item.end_col <= 0 then
            return #fin_line
        end

        if item.vcol == 1 then
            return eu._vcol_to_end__col(item.col, fin_line)
        end

        -- Diagnostic end_col values are end_exclusive
        local end_idx_ = math.min(item.end_col - 1, #fin_line) --- @type integer
        if fin_row == row and end_idx_ == col then
            end_idx_ = end_idx_ + 1
        end

        return end_idx_
    end)() --- @type integer

    return { row, col, fin_row, fin_col_ }
end

--- @param preview_buf integer
--- @param item vim.quickfix.entry
--- @return nil
local function set_err_range_extmark(preview_buf, item)
    local hl_range = range_qf_to_zero_(preview_buf, item) --- @type Range4
    if not hl_range then
        if extmarks[preview_buf] then
            vim.api.nvim_buf_del_extmark(preview_buf, hl_ns, extmarks[preview_buf])
        end

        return
    end

    extmarks[preview_buf] =
        vim.api.nvim_buf_set_extmark(preview_buf, hl_ns, hl_range[1], hl_range[2], {
            hl_group = "QfRancherHighlightItem",
            id = extmarks[preview_buf],
            end_row = hl_range[3],
            end_col = hl_range[4],
            priority = 200,
            strict = false,
        })
end

--- @param item_buf integer
--- @param preview_buf integer
--- @return nil
local function setup_hls(item_buf, preview_buf)
    local item_ft = vim.filetype.match({ buf = item_buf }) or "" --- @type string
    if item_ft == "" then
        vim.api.nvim_set_option_value("syntax", item_ft, { buf = preview_buf })
        return
    end

    local item_lang = vim.treesitter.language.get_lang(item_ft) or item_ft --- @type string
    --- @type vim.treesitter.LanguageTree?
    local parser = vim.treesitter.get_parser(preview_buf, item_lang, { error = false })
    if parser then
        vim.treesitter.start(preview_buf, item_lang)
    else
        vim.api.nvim_set_option_value("syntax", item_ft, { buf = preview_buf })
    end
end

--- @param item_buf integer
--- @param lines string[]
--- @return nil
local function create_preview_buf_from_lines(item_buf, lines)
    local ey = require("mjm.error-list-types")
    ey._validate_buf(item_buf)
    ey._validate_str_list(lines)

    local preview_buf = vim.api.nvim_create_buf(false, false) --- @type integer
    vim.api.nvim_buf_set_lines(preview_buf, 0, 0, false, lines)

    vim.api.nvim_set_option_value("buflisted", false, { buf = preview_buf })
    -- NOTE: Setting a non-"" buftype prevents LSPs from attaching
    vim.api.nvim_set_option_value("buftype", "nowrite", { buf = preview_buf })
    vim.api.nvim_set_option_value("modifiable", false, { buf = preview_buf })
    vim.api.nvim_set_option_value("readonly", true, { buf = preview_buf })
    vim.api.nvim_set_option_value("swapfile", false, { buf = preview_buf })
    vim.api.nvim_set_option_value("undofile", false, { buf = preview_buf })

    setup_hls(item_buf, preview_buf)
    return preview_buf
end

--- @param item vim.quickfix.entry
--- @return nil
local function setup_preview_buf(item)
    local ey = require("mjm.error-list-types")
    ey._validate_list_item(item)
    ey._validate_uint(item.bufnr)

    if not bufs[item.bufnr] then
        local lines = (function()
            if not vim.api.nvim_buf_is_valid(item.bufnr) then
                return { item.bufnr .. " is not valid" }
            end

            if vim.api.nvim_buf_is_loaded(item.bufnr) then
                return vim.api.nvim_buf_get_lines(item.bufnr, 0, -1, false)
            end

            local full_path = vim.api.nvim_buf_get_name(item.bufnr) --- @type string
            if vim.uv.fs_access(full_path, 4) then
                return vim.fn.readfile(full_path, "")
            end

            return { "Unable to read lines for bufnr " .. item.bufnr }
        end)() --- @type string[]

        bufs[item.bufnr] = create_preview_buf_from_lines(item.bufnr, lines)
    end

    set_err_range_extmark(bufs[item.bufnr], item)
end

-------------------------
--- OPEN/CLOSE/UPDATE ---
-------------------------

--- @return nil
function M._update_preview_win_buf()
    assert(preview_state:is_open())
    assert(preview_state:is_cur_list_win(vim.api.nvim_get_current_win()))

    local wintype = vim.fn.win_gettype(preview_state.list_win)
    local is_loclist = wintype == "loclist" --- @type boolean
    local src_win = is_loclist and preview_state.list_win or nil --- @type integer|nil
    --- @type vim.quickfix.entry[]
    local items = require("mjm.error-list-tools")._get_items(src_win, 0)
    if #items < 1 then
        return
    end

    local line = vim.fn.line(".") --- @type integer
    assert(line <= #items)

    local item = items[line] --- @type vim.quickfix.entry
    if not item.bufnr then
        return
    end

    setup_preview_buf(item)
    vim.api.nvim_win_set_buf(preview_state.preview_win, bufs[item.bufnr])
    set_preview_win_title(bufs[item.bufnr])

    local eu = require("mjm.error-list-util") --- @type QfRancherUtils
    eu._protected_set_cursor(preview_state.preview_win, { item.lnum, item.col - 1 })
    vim.api.nvim_win_call(preview_state.preview_win, function()
        vim.api.nvim_cmd({ cmd = "normal", args = { "zz" }, bang = true }, {})
        vim.api.nvim_cmd({ cmd = "normal", args = { "ze" }, bang = true }, {})
    end)
end

--- @param do_zzze? boolean
--- @return nil
function M._update_preview_win_pos(do_zzze)
    if not preview_state:is_open() then
        return
    end

    assert(preview_state:is_cur_list_win(vim.api.nvim_get_current_win()))
    vim.validate("do_zzze", do_zzze, "boolean", true)

    local win_cfg = get_win_cfg(preview_state.list_win) --- @type vim.api.keyset.win_config
    vim.api.nvim_win_set_config(preview_state.preview_win, win_cfg)

    if do_zzze then
        vim.api.nvim_win_call(preview_state.preview_win, function()
            vim.api.nvim_cmd({ cmd = "normal", args = { "zz" }, bang = true }, {})
            vim.api.nvim_cmd({ cmd = "normal", args = { "ze" }, bang = true }, {})
        end)
    end
end

--- @return nil
function M.update_preview_win_pos()
    if preview_state:is_open() then
        M._update_preview_win_pos()
    end
end

--- @param list_win integer
--- @return nil
function M.open_preview_win(list_win)
    require("mjm.error-list-types")._validate_list_win(list_win)

    if preview_state:is_open() then
        return
    end

    local wintype = vim.fn.win_gettype(list_win)
    local is_loclist = wintype == "loclist" --- @type boolean
    local src_win = is_loclist and list_win or nil --- @type integer|nil
    --- @type vim.quickfix.entry[]
    local items = require("mjm.error-list-tools")._get_items(src_win, 0)
    if #items < 1 then
        return
    end

    local line = vim.fn.line(".") --- @type integer
    assert(line <= #items)

    local item = items[line] --- @type vim.quickfix.entry
    if not item.bufnr then
        return
    end

    setup_preview_buf(item)
    local win_cfg = get_win_cfg(list_win) --- @type vim.api.keyset.win_config
    local preview_win = create_preview_win(win_cfg, bufs[item.bufnr])
    preview_state:set(list_win, preview_win)

    local eu = require("mjm.error-list-util")
    eu._protected_set_cursor(preview_state.preview_win, { item.lnum, item.col - 1 })
    vim.api.nvim_win_call(preview_win, function()
        vim.api.nvim_cmd({ cmd = "normal", args = { "zz" }, bang = true }, {})
        vim.api.nvim_cmd({ cmd = "normal", args = { "ze" }, bang = true }, {})
    end)

    set_preview_win_title(bufs[item.bufnr])
    create_autocmds()
end

--- @return nil
function M._close_preview_win()
    if preview_state:is_open() then
        close_and_clear()
    end
end

--- @param list_win integer
--- @return nil
function M.toggle_preview_win(list_win)
    require("mjm.error-list-types")._validate_list_win(list_win)

    local was_open = preview_state:is_open()
    local start_list_win = preview_state.list_win
    if was_open then
        M._close_preview_win()
    end

    if was_open and list_win == start_list_win then
        return
    else
        M.open_preview_win(list_win)
    end
end

return M

------------
--- TODO ---
------------

--- Do a Grok audit on this module when complete. It's self-contained enough that it should work

--- Check that all functions have reasonable default sorts
--- Check that window height updates are triggered where appropriate
--- Check that functions have proper visibility
--- Check that all mappings have plugs and cmds
--- Check that all maps/cmds/plugs have desc fieldss
--- Check that all functions have annotations and documentation

-----------
--- MID ---
-----------

--- If the file has to be read fresh, that should be handled async
--- - Study Lua co-routines, built-in async lib, and lewis's async lib

-----------
--- LOW ---
-----------

--- Customize how error is emphasized. Cursor row/column? Visual line on lnum?
--- Add scrolling to preview win
---     See https://github.com/bfrg/vim-qf-preview for relevant controls
--- Add an option to autoshow the preview
