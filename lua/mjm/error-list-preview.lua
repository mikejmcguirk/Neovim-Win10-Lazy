local eu = Qfr_Defer_Require("mjm.error-list-util") ---@type QfrUtil
local ey = Qfr_Defer_Require("mjm.error-list-types") ---@type QfrTypes

---@class QfRancherPreview
local M = {}

local set_opt = vim.api.nvim_set_option_value

-------------------
--- MODULE DATA ---
-------------------

local hl_ns = vim.api.nvim_create_namespace("qf-rancher-preview-hl") ---@type integer

-- DOCUMENT: This highlight group
local hl_name = "QfRancherHighlightItem" ---@type string
local cur_hl = vim.api.nvim_get_hl(0, { name = hl_name }) ---@type vim.api.keyset.get_hl_info
if (not cur_hl) or #vim.tbl_keys(cur_hl) == 0 then
    -- DOCUMENT: That this links to CurSearch by default
    vim.api.nvim_set_hl(0, hl_name, { link = "CurSearch" })
end

---@class QfRancherPreviewState
---@field preview_win integer|nil
---@field list_win integer|nil

local preview_state = {
    preview_win = nil,
    list_win = nil,
} ---@type QfRancherPreviewState

---@param self QfRancherPreviewState
---@param list_win integer
---@param preview_win integer
---@return nil
function preview_state:set(list_win, preview_win)
    ey._validate_list_win(list_win)
    ey._validate_win(preview_win)

    self.list_win = list_win
    self.preview_win = preview_win
end

---@param list_win integer
---@param preview_win integer
---@return boolean
local function is_preview_open(list_win, preview_win)
    return ey._is_uint(list_win) and ey._is_uint(preview_win)
end

---@param list_win integer
---@param preview_win integer
---@return boolean
local function is_preview_closed(list_win, preview_win)
    return type(list_win) == "nil" and type(preview_win) == "nil"
end

---@param list_win integer
---@param preview_win integer
---@return nil
local function validate_state(list_win, preview_win)
    ey._validate_list_win(list_win, true)
    ey._validate_win(preview_win, true)
    assert(is_preview_open(list_win, preview_win) or is_preview_closed(list_win, preview_win))
end

---@param self QfRancherPreviewState
---@return boolean
function preview_state:is_open()
    validate_state(self.list_win, self.preview_win)
    return is_preview_open(self.list_win, self.preview_win)
end

---@param self QfRancherPreviewState
---@return nil
function preview_state:clear()
    self.preview_win = nil
    self.list_win = nil
end

---@param self QfRancherPreviewState
---@return boolean
function preview_state:is_cur_list_win(win)
    validate_state(self.list_win, self.preview_win)
    return win == self.list_win
end

local bufs = {} ---@type integer[]
local extmarks = {} ---@type integer[]

local group_name = "qf-rancher-preview-group" ---@type string
local group = vim.api.nvim_create_augroup(group_name, {}) ---@type integer

local SCROLLOFF = 6 ---@type integer

---@return nil
local function close_and_clear()
    if preview_state:is_open() then
        eu._pwin_close(preview_state.preview_win, true)
        preview_state:clear()
    end
end

---@return nil
local function clear_session_data()
    close_and_clear()

    for _, buf in pairs(bufs) do
        eu._pbuf_rm(buf, true, true)
    end

    bufs = {}
    extmarks = {}

    ---@type vim.api.keyset.get_autocmds.ret[]
    local autocmds = vim.api.nvim_get_autocmds({ group = group })
    for _, autocmd in pairs(autocmds) do
        vim.api.nvim_del_autocmd(autocmd.id)
    end
end

---@return boolean
local function has_no_list_wins()
    local qf_wins = eu._get_qf_wins({ all_tabpages = true }) ---@type integer[]
    local ll_wins = eu._get_all_loclist_wins({ all_tabpages = true }) ---@type integer[]

    return #qf_wins == 0 and #ll_wins == 0
end

---@return nil
local function checked_session_clear()
    if has_no_list_wins() then clear_session_data() end
end

local checked_clear_idle_handle = nil ---@type uv.uv_idle_t|nil

---@return nil
local function checked_clear_when_idle()
    if checked_clear_idle_handle then return end

    checked_clear_idle_handle = vim.uv.new_idle()
    if not checked_clear_idle_handle then
        checked_session_clear()
        return
    end

    checked_clear_idle_handle:start(function()
        -- This has the side benefit of ensuring that closed windows are removed from the layout
        vim.schedule(function()
            checked_session_clear()
        end)

        checked_clear_idle_handle:stop()
        checked_clear_idle_handle:close()
        checked_clear_idle_handle = nil
    end)
end

-- MID: Figure out what events history and filter are triggering

---@return nil
local function create_autocmds()
    if #vim.api.nvim_get_autocmds({ group = group }) > 0 then return end

    assert(preview_state:is_open())

    local list_win_buf = vim.api.nvim_win_get_buf(preview_state.list_win) ---@type integer

    vim.api.nvim_create_autocmd("CursorMoved", {
        group = group,
        buffer = list_win_buf,
        callback = function()
            M.update_preview_win_pos()
            M._update_preview_win_buf()
        end,
    })

    vim.api.nvim_create_autocmd("BufLeave", {
        group = group,
        buffer = list_win_buf,
        callback = function()
            close_and_clear()
            checked_clear_when_idle()
        end,
    })

    vim.api.nvim_create_autocmd("WinClosed", {
        group = group,
        callback = function()
            checked_clear_when_idle()
        end,
    })

    -- Here to account for situations where WinLeave does not fire properly
    vim.api.nvim_create_autocmd("WinEnter", {
        group = group,
        callback = function()
            if not preview_state:is_cur_list_win(vim.api.nvim_get_current_win()) then
                M.close_preview_win()
            end
        end,
    })

    vim.api.nvim_create_autocmd("WinLeave", {
        group = group,
        callback = function()
            if preview_state:is_cur_list_win(vim.api.nvim_get_current_win()) then
                M.close_preview_win()
            end
        end,
    })

    vim.api.nvim_create_autocmd("WinResized", {
        group = group,
        callback = function()
            M.update_preview_win_pos()
        end,
    })
end

--------------------
--- WINDOW SETUP ---
--------------------

---@param item_buf integer
---@return vim.api.keyset.win_config
local function get_title_cfg(item_buf)
    -- Do not assert item_buf is not nil because nils are valid in qf entries
    -- Do not assert that item_buf is valid since a buf can be wiped after the list is created
    ey._validate_uint(item_buf, true)

    if not eu._get_g_var("qf_rancher_preview_show_title") then return { title = nil } end

    if not (item_buf and vim.api.nvim_buf_is_valid(item_buf)) then
        return { title = "No buffer" }
    end

    local preview_name = vim.api.nvim_buf_get_name(item_buf) ---@type string
    local relative_name = vim.fn.fnamemodify(preview_name, ":.") ---@type string
    local g_title_pos = eu._get_g_var("qf_rancher_preview_title_pos") ---@type QfRancherTitlePos
    return { title = relative_name, title_pos = g_title_pos }
end

---@return QfRancherBorder
local function get_winborder()
    ---@type QfRancherBorder|nil
    local border = eu._get_g_var("qf_rancher_preview_border", true)
    if border then return border end

    local winborder = vim.fn.has("nvim-0.11")
            and vim.api.nvim_get_option_value("winborder", { global = true })
        or "single"

    if winborder ~= "" then
        return winborder
    else
        return "single"
    end
end

local MIN_WIDTH = 79 ---@type integer
local MIN_HEIGHT = 6 ---@type integer
local MAX_HEIGHT = 24 ---@type integer

---@param base_cfg table
---@param e_lines integer
---@param e_cols integer
---@param padding integer
---@param preview_border_width integer
---@return table
local function get_fallback_win_config(base_cfg, e_lines, e_cols, padding, preview_border_width)
    local height = math.floor(e_lines * 0.4) ---@type integer
    height = math.min(height, MAX_HEIGHT)
    local fallback_base = vim.tbl_extend("force", base_cfg, {
        relative = "tabline",
        height = height,
        width = e_cols - (padding * 2) - preview_border_width,
        col = 1,
    }) ---@type vim.api.keyset.win_config

    local screenrow = vim.fn.screenrow() ---@type integer
    local half_way = e_lines * 0.5 ---@type number
    if screenrow <= half_way then
        return vim.tbl_extend("force", fallback_base, { row = math.floor(e_lines * 0.6) })
    else
        return vim.tbl_extend("force", fallback_base, { row = 0 })
    end
end

---@param list_win integer
---@param item_buf? integer
---@return vim.api.keyset.win_config
local function get_win_cfg(list_win, item_buf)
    ey._validate_list_win(list_win)
    ey._validate_uint(item_buf, true)

    local list_win_pos = vim.api.nvim_win_get_position(list_win) ---@type [integer, integer]
    local list_win_height = vim.api.nvim_win_get_height(list_win) ---@type integer
    local list_win_width = vim.api.nvim_win_get_width(list_win) ---@type integer
    local e_lines = vim.api.nvim_get_option_value("lines", { scope = "global" }) ---@type integer
    local e_cols = vim.api.nvim_get_option_value("columns", { scope = "global" }) ---@type integer

    local border = get_winborder() ---@type QfRancherBorder
    local preview_border_cells = border ~= "none" and 2 or 0 ---@type integer
    local vim_separator = 1 ---@type integer
    local padding = 1 ---@type integer

    -- Window width and height only account for the inside of the window, not its borders. For
    -- consistency, track the target internal size of the window separately from the space needed
    -- to render the window plus the borders and padding
    local min_x = MIN_WIDTH + (padding * 2) + preview_border_cells ---@type integer
    local min_y = MIN_HEIGHT + preview_border_cells ---@type integer

    local base_cfg = { border = border, focusable = false } ---@type vim.api.keyset.win_config
    base_cfg = item_buf and vim.tbl_extend("force", base_cfg, get_title_cfg(item_buf)) or base_cfg
    ---@type vim.api.keyset.win_config
    local win_cfg = vim.tbl_extend("force", base_cfg, { relative = "win", win = list_win })

    local avail_y_above = math.max(list_win_pos[1] - vim_separator - 1, 0) ---@type integer
    ---@type integer
    local avail_y_below = e_lines - (list_win_pos[1] + list_win_height + vim_separator + 1)
    local avail_x_left = math.max(list_win_pos[2] - vim_separator, 0) ---@type integer
    ---@type integer
    local avail_x_right = math.max(e_cols - (list_win_pos[2] + list_win_width + vim_separator), 0)
    local avail_width = list_win_width - (padding * 2) - preview_border_cells ---@type integer
    local avail_e_width = e_cols - (padding * 2) - preview_border_cells ---@type integer

    -- NOTE: Prefer rendering previews with spill into other wins to keep the direction
    -- they appear as consistent as possible

    ---@param height integer
    ---@param row integer
    ---@return vim.api.keyset.win_config
    local function cfg_vert_spill(height, row)
        local x_diff = min_x - list_win_width ---@type integer
        local half_diff = math.ceil(x_diff * 0.5) ---@type integer
        local r_shift = math.max(half_diff - avail_x_left, 0) ---@type integer
        local l_shift = math.max(half_diff - avail_x_right, 0) ---@type integer
        return vim.tbl_extend("force", win_cfg, {
            height = height,
            row = row,
            width = math.min(MIN_WIDTH, avail_e_width),
            col = (half_diff * -1) + r_shift - l_shift + 1,
        })
    end

    if avail_y_above >= min_y then
        local height = avail_y_above - preview_border_cells ---@type integer
        height = math.min(height, MAX_HEIGHT)
        local row = (height + preview_border_cells + vim_separator) * -1 ---@type integer
        if list_win_width >= min_x then
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

    if avail_y_below >= min_y then
        local height = avail_y_below - preview_border_cells ---@type integer
        height = math.min(height, MAX_HEIGHT)
        local row = list_win_height + vim_separator ---@type integer
        if list_win_width >= min_x then
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

    local avail_height = list_win_height - (padding * 2) - preview_border_cells ---@type integer
    local avail_e_lines = e_lines - preview_border_cells ---@type integer
    local side_height = math.min(avail_height, MAX_HEIGHT) ---@type integer

    ---@param width integer
    ---@param col integer
    ---@return vim.api.keyset.win_config
    local function cfg_hor_spill(width, col)
        local y_diff = min_y - list_win_height ---@type integer
        local half_diff = math.floor(y_diff * 0.5) ---@type integer
        local u_shift = math.max(half_diff - avail_y_above, 0) ---@type integer
        local d_shift = math.max(half_diff - avail_y_below, 0) ---@type integer
        return vim.tbl_extend("force", win_cfg, {
            height = math.min(MIN_HEIGHT, avail_e_lines),
            row = (half_diff * -1) - u_shift + d_shift - 1,
            width = width,
            col = col,
        })
    end

    ---@return vim.api.keyset.win_config
    local function open_left()
        local col = (list_win_pos[2] - vim_separator) * -1 ---@type integer
        local width = avail_x_left - (padding * 2) - preview_border_cells ---@type integer
        if list_win_height >= min_y then
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

    ---@return vim.api.keyset.win_config
    local function open_right()
        local col = list_win_pos[2] + list_win_width + vim_separator + padding ---@type integer
        local width = avail_x_right - (padding * 2) - preview_border_cells ---@type integer
        if list_win_height >= min_y then
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
        if avail_x_right >= min_x then
            return open_right()
        elseif avail_x_left >= min_x then
            return open_left()
        end
    else
        if avail_x_left >= min_x then
            return open_left()
        elseif avail_x_right >= min_x then
            return open_right()
        end
    end

    return get_fallback_win_config(base_cfg, e_lines, e_cols, padding, preview_border_cells)
end

---@param win_cfg vim.api.keyset.win_config
---@param preview_buf integer
---@return integer
local function create_preview_win(win_cfg, preview_buf)
    vim.validate("win_cfg", win_cfg, "table")
    ey._validate_buf(preview_buf)

    local preview_win = vim.api.nvim_open_win(preview_buf, false, win_cfg) ---@type integer

    set_opt("cc", "", { win = preview_win })
    set_opt("cul", true, { win = preview_win })

    set_opt("fdc", "0", { win = preview_win })
    set_opt("fdm", "manual", { win = preview_win })

    set_opt("list", false, { win = preview_win })

    set_opt("nu", true, { win = preview_win })
    set_opt("rnu", false, { win = preview_win })
    set_opt("scl", "no", { win = preview_win })
    set_opt("stc", "", { win = preview_win })

    set_opt("spell", false, { win = preview_win })

    ---@type integer
    local g_winblend = eu._get_g_var("qf_rancher_preview_winblend")
    set_opt("winblend", g_winblend, { win = preview_win })

    set_opt("so", SCROLLOFF, { win = preview_win })
    set_opt("siso", SCROLLOFF, { win = preview_win })

    return preview_win
end

-----------------
--- BUF SETUP ---
-----------------

---@param preview_buf integer
---@param item table
---@return Range4
local function range_qf_to_zero_(preview_buf, item)
    ey._validate_buf(preview_buf)
    ey._validate_list_item(item)

    local row = item.lnum > 0 and item.lnum - 1 or 0 ---@type integer
    row = math.min(row, vim.api.nvim_buf_line_count(preview_buf) - 1)

    ---@type string
    local start_line = vim.api.nvim_buf_get_lines(preview_buf, row, row + 1, false)[1]
    local col = (function()
        if item.col <= 0 then return 0 end

        if item.vcol == 1 then
            ---@type boolean, integer, integer
            local _, start_byte, _ = eu._vcol_to_byte_bounds(item.col, start_line)
            return start_byte
        else
            return math.min(item.col - 1, #start_line - 1)
        end
    end)() ---@type integer

    local fin_row = item.end_lnum > 0 and item.end_lnum - 1 or row ---@type integer
    fin_row = math.max(fin_row, row)

    ---@type string
    local fin_line = fin_row == row and start_line
        or vim.api.nvim_buf_get_lines(preview_buf, fin_row, fin_row + 1, false)[1]
    local fin_col_ = (function()
        if item.end_col <= 0 then return #fin_line end

        if item.vcol == 1 then return eu._vcol_to_end_col_(item.col, fin_line) end

        local end_idx_ = math.min(item.end_col - 1, #fin_line) ---@type integer
        if fin_row == row and end_idx_ == col then end_idx_ = end_idx_ + 1 end

        return end_idx_
    end)() ---@type integer

    return { row, col, fin_row, fin_col_ }
end

---@param preview_buf integer
---@param item vim.quickfix.entry
---@return nil
local function set_err_range_extmark(preview_buf, item)
    local hl_range = range_qf_to_zero_(preview_buf, item) ---@type Range4
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

---@param preview_buf integer
---@return nil
local function set_preview_buf_opts(preview_buf)
    ey._validate_buf(preview_buf)

    set_opt("buflisted", false, { buf = preview_buf })
    -- NOTE: Setting a non-"" buftype prevents LSPs from attaching
    set_opt("buftype", "nofile", { buf = preview_buf })
    set_opt("modifiable", false, { buf = preview_buf })
    set_opt("readonly", true, { buf = preview_buf })
    set_opt("swapfile", false, { buf = preview_buf })
    set_opt("undofile", false, { buf = preview_buf })
end

---@return integer
local function create_fallback_buf()
    local buf = vim.api.nvim_create_buf(false, true) ---@type integer

    set_opt("bufhidden", "wipe", { buf = buf })
    set_preview_buf_opts(buf)

    local lines = { "No bufnr for this list entry" } ---@type string[]
    vim.api.nvim_buf_set_lines(buf, 0, 0, false, lines)

    return buf
end

---@param item_buf integer
---@return string[]
local function get_lines(item_buf)
    -- Do not assert that item_buf is valid since a buf can be wiped after the list is created
    ey._validate_uint(item_buf)

    if not vim.api.nvim_buf_is_valid(item_buf) then return { item_buf .. " is not valid" } end

    if vim.api.nvim_buf_is_loaded(item_buf) then
        return vim.api.nvim_buf_get_lines(item_buf, 0, -1, false)
    end

    local full_path = vim.api.nvim_buf_get_name(item_buf) ---@type string
    if vim.uv.fs_access(full_path, 4) then return vim.fn.readfile(full_path, "") end

    return { "Unable to read lines for bufnr " .. item_buf }
end

---@param item_buf integer
---@return nil
local function update_preview_buf(item_buf)
    -- This function should only called because of a changedtick update in a known valid buffer
    ey._validate_buf(item_buf, true)
    ey._validate_buf(bufs[item_buf], true)

    local lines = get_lines(item_buf) ---@type string[]
    set_opt("modifiable", true, { buf = bufs[item_buf] })
    pcall(vim.api.nvim_buf_set_lines, bufs[item_buf], 0, -1, false, lines)
    set_opt("modifiable", false, { buf = bufs[item_buf] })
end

---@param item_buf integer
---@return integer
local function get_mtime(item_buf)
    ey._validate_buf(item_buf)

    local item_buf_full_path = vim.api.nvim_buf_get_name(item_buf) ---@type string
    local stat = vim.uv.fs_stat(item_buf_full_path) ---@type uv.fs_stat.result|nil
    return stat and stat.mtime.sec or 0
end

---@param item_buf integer
---@param lines string[]
---@return nil
local function create_preview_buf_from_lines(item_buf, lines)
    -- Do not assert that item_buf is valid since a buf can be wiped after the list is created
    ey._validate_uint(item_buf)
    ey._validate_list(lines, { type = "string" })

    local preview_buf = vim.api.nvim_create_buf(false, true) ---@type integer
    vim.api.nvim_buf_set_lines(preview_buf, 0, 0, false, lines)
    set_preview_buf_opts(preview_buf)

    if not vim.api.nvim_buf_is_valid(item_buf) then return preview_buf end

    local src_changedtick = vim.api.nvim_buf_get_changedtick(item_buf) ---@type integer
    vim.api.nvim_buf_set_var(preview_buf, "src_changedtick", src_changedtick)
    vim.api.nvim_buf_set_var(preview_buf, "src_mtime", get_mtime(item_buf))

    local item_ft = vim.api.nvim_get_option_value("filetype", { buf = item_buf }) ---@type string
    item_ft = item_ft ~= "" and item_ft or (vim.filetype.match({ buf = item_buf }) or "")
    if item_ft == "" then
        set_opt("syntax", item_ft, { buf = preview_buf })
        return preview_buf
    end

    local item_lang = vim.treesitter.language.get_lang(item_ft) or item_ft ---@type string
    -- LOW: Has to be a more efficient way to do this
    -- TODO: If we can't get out of this, note that at some point a change will be made in 0.12 to
    --  make error = false the default behavior and remove the option. This will require a has()
    --  check to determine which syntax is used to run the check
    if vim.treesitter.get_parser(preview_buf, item_lang, { error = false }) then
        pcall(vim.treesitter.start, preview_buf, item_lang)
    else
        set_opt("syntax", item_ft, { buf = preview_buf })
    end

    return preview_buf
end

---@param item vim.quickfix.entry
---@return integer
local function get_preview_buf(item)
    ey._validate_list_item(item)

    if not item.bufnr then return create_fallback_buf() end

    if not bufs[item.bufnr] then
        local lines = get_lines(item.bufnr) ---@type string[]
        bufs[item.bufnr] = create_preview_buf_from_lines(item.bufnr, lines)
    elseif vim.api.nvim_buf_is_valid(item.bufnr) then
        local src_changedtick = vim.api.nvim_buf_get_changedtick(item.bufnr) ---@type integer
        local src_mtime = get_mtime(item.bufnr) ---@type integer

        ---@type boolean
        local changedtick_updated = src_changedtick ~= vim.b[bufs[item.bufnr]].src_changedtick
        local mtime_updated = src_mtime ~= vim.b[bufs[item.bufnr]].src_mtime ---@type boolean
        if changedtick_updated or mtime_updated then
            vim.api.nvim_buf_set_var(bufs[item.bufnr], "src_changedtick", src_changedtick)
            vim.api.nvim_buf_set_var(bufs[item.bufnr], "src_mtime", src_mtime)
            update_preview_buf(item.bufnr)
        end
    end

    set_err_range_extmark(bufs[item.bufnr], item)

    return bufs[item.bufnr]
end

-------------------------
--- OPEN/CLOSE/UPDATE ---
-------------------------

local timer = vim.uv.new_timer() ---@type uv.uv_timer_t|nil
local queued_update = false ---@type boolean

---@return nil
local function at_timer_end()
    if queued_update then
        queued_update = false
        vim.schedule(M._update_preview_win_buf)
    end

    if timer then
        timer:stop()
        timer:close()
        timer = nil
    end
end

local function start_timer()
    timer = timer or vim.uv.new_timer()
    if timer then timer:start(eu._get_g_var("qf_rancher_preview_debounce"), 0, at_timer_end) end
end

---@param list_win integer
---@return vim.quickfix.entry|nil
local function get_list_item(list_win)
    ey._validate_list_win(list_win)

    local wintype = vim.fn.win_gettype(list_win)
    local is_loclist = wintype == "loclist" ---@type boolean
    local src_win = is_loclist and list_win or nil ---@type integer|nil

    return eu._get_item_under_cursor(src_win)
end

---@return nil
function M._update_preview_win_buf()
    if timer and timer:get_due_in() > 0 then
        queued_update = true
        return
    end

    if not preview_state:is_open() then return end

    if not preview_state:is_cur_list_win(vim.api.nvim_get_current_win()) then return end

    local item = get_list_item(preview_state.list_win) ---@type vim.quickfix.entry|nil
    if not item then return end

    local preview_buf = get_preview_buf(item) ---@type integer
    vim.api.nvim_win_set_buf(preview_state.preview_win, preview_buf)
    vim.api.nvim_win_set_config(preview_state.preview_win, get_title_cfg(item.bufnr))

    eu._protected_set_cursor(preview_state.preview_win, eu._qf_pos_to_cur_pos(item.lnum, item.col))
    eu._do_zzze(preview_state.preview_win)

    start_timer()
end

---@return nil
function M.update_preview_win_pos()
    if not preview_state:is_open() then return end

    local win_cfg = get_win_cfg(preview_state.list_win) ---@type vim.api.keyset.win_config
    vim.api.nvim_win_set_config(preview_state.preview_win, win_cfg)

    eu._do_zzze(preview_state.preview_win)
end

---@param list_win integer
---@return nil
function M.open_preview_win(list_win)
    if preview_state:is_open() then return end

    ey._validate_list_win(list_win)

    local item = get_list_item(list_win) ---@type vim.quickfix.entry|nil
    if not item then return end

    -- Do this first in anticipation of future async file read
    local preview_buf = get_preview_buf(item) ---@type integer
    local win_cfg = get_win_cfg(list_win, item.bufnr) ---@type vim.api.keyset.win_config
    local preview_win = create_preview_win(win_cfg, preview_buf)
    preview_state:set(list_win, preview_win)

    eu._protected_set_cursor(preview_state.preview_win, eu._qf_pos_to_cur_pos(item.lnum, item.col))
    eu._do_zzze(preview_state.preview_win)
    create_autocmds()

    start_timer()
end

---@return nil
function M.close_preview_win()
    close_and_clear()
end

---@param list_win integer
---@return nil
function M.toggle_preview_win(list_win)
    if not ey._is_in_list_win(list_win) then return end

    local was_open = preview_state:is_open() ---@type boolean
    local start_list_win = preview_state.list_win ---@type integer|nil
    if was_open then M.close_preview_win() end

    if was_open and list_win == start_list_win then
        return
    else
        M.open_preview_win(list_win)
    end
end

return M

---------------
--- CREDITS ---
---------------

--- https://github.com/r0nsha/qfpreview.nvim

------------
--- TODO ---
------------

--- Testing
--- Docs

-----------
--- MID ---
-----------

--- If the file has to be read fresh, that should be handled async
--- - Study Lua co-routines, built-in async lib, and lewis's async lib
--- - Trouble also uses a mini-async library
--- Allow one open preview win per tabpage
--- Make the baseline window dimensions configurable

-----------
--- LOW ---
-----------

--- Customize how error is emphasized. Cursor row/column? Visual line on lnum?
--- Add scrolling to preview win
---     See https://github.com/bfrg/vim-qf-preview for relevant controls
--- Add an option to autoshow the preview
--- Always updating and reading changedtick and mtime is not the most efficient. But the current
---     way also avoids the extra logic of tracking which is being used as well as bufloaded
