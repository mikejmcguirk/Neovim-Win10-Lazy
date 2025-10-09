local M = {}

--------------
--- Config ---
--------------

local hl_ns = vim.api.nvim_create_namespace("qf-rancher-preview-hl")

-- DOCUMENT: This highlight group
local hl_name = "QfRancherHighlightItem" --- @type string
local cur_hl = vim.api.nvim_get_hl(0, { name = hl_name }) --- @type vim.api.keyset.get_hl_info
if (not cur_hl) or #vim.tbl_keys(cur_hl) == 0 then
    -- DOCUMENT: That this links to CurSearch by default
    vim.api.nvim_set_hl(0, hl_name, { link = "CurSearch" })
end

-- TODO: The autocmd for this should resolve in the "plugin" file. I don't see the need for the
-- autocmd to run if it does nothing
vim.api.nvim_set_var("qf_rancher_preview_autoshow", false)
-- vim.api.nvim_set_var("qf_rancher_preview_border", "single")
vim.api.nvim_set_var("qf_rancher_preview_show_title", false)
-- vim.api.nvim_set_var("qf_rancher_preview_title_pos", "center")
vim.api.nvim_set_var("qf_rancher_preview_use_global_so", false)
vim.api.nvim_set_var("qf_rancher_preview_use_global_siso", false)
-- vim.api.nvim_set_var("qf_rancher_preview_winblend", 0)

---------------------
--- Session State ---
---------------------

local group_name = "qf-rancher-preview-group" --- @type string
local group = vim.api.nvim_create_augroup(group_name, { clear = true }) --- @type integer

local old_bad_preview_win = nil --- @type integer|nil
local old_bad_qf_win = nil --- @type integer|nil

local wins = {} --- @type integer[]
local bufs = {} --- @type integer[]
local extmarks = {} --- @type integer[]

-------------------------
--- Session Functions ---
-------------------------

--- @return nil
local function clear_session_data()
    -- TEST: That this deletes the extmarks as well
    for _, preview_win in pairs(wins) do
        if vim.api.nvim_win_is_valid(preview_win) then
            vim.api.nvim_win_close(preview_win, true)
        end
    end

    for _, bufnr in pairs(bufs) do
        if vim.api.nvim_buf_is_valid(bufnr) then
            vim.api.nvim_buf_delete(bufnr, { force = true })
        end
    end

    wins = {}
    bufs = {}
    extmarks = {}

    local autocmds = vim.api.nvim_get_autocmds({ group = group })
    for _, a in pairs(autocmds) do
        vim.api.nvim_del_autocmd(a.id)
    end
end

--- @return boolean
local function check_session_validity()
    if #vim.tbl_keys(wins) > 0 then
        return true
    end

    local eu = require("mjm.error-list-util") --- @type QfRancherUtils
    local qf_wins = eu._get_qf_wins({ all_tabpages = true }) --- @type integer[]
    local ll_wins = eu._get_all_loclist_wins({ all_tabpages = true }) --- @type integer[]

    return #qf_wins > 0 or #ll_wins > 0
end

local function create_autocmds()
    if #vim.api.nvim_get_autocmds({ group = group }) > 0 then
        return
    end

    vim.api.nvim_create_autocmd("CursorMoved", {
        group = group,
        callback = function()
            local cur_win = vim.api.nvim_get_current_win() --- @type integer
            local preview_win = wins[cur_win] --- @type integer|nil
            if preview_win and preview_win > 0 then
                M.update_preview_win(preview_win)
            end
        end,
    })

    vim.api.nvim_create_autocmd("BufEnter", {
        group = group,
        callback = function(ev)
            local win = vim.api.nvim_get_current_win() --- @type integer
            local ft = vim.api.nvim_get_option_value("filetype", { buf = ev.buf }) --- @type string
            wins[win] = (wins[win] and ft == "qf") and wins[win] or nil --- @type integer|nil

            if not check_session_validity() then
                clear_session_data()
            end
        end,
    })

    vim.api.nvim_create_autocmd("WinClosed", {
        group = group,
        callback = function(ev)
            local closed_win = tonumber(ev.match)
            if closed_win ~= nil then
                wins[closed_win] = nil
            end

            if not check_session_validity() then
                clear_session_data()
            end
        end,
    })

    -- TODO: Test with FzfLua/Blink/Harpoon to see if this is necessary
    -- vim.api.nvim_create_autocmd("WinEnter", {
    --     group = group,
    --     callback = function()
    --         local cur_win = vim.api.nvim_get_current_win()
    --         if cur_win ~= old_bad_qf_win then
    --             M.close_preview_win()
    --         end
    --     end,
    -- })

    vim.api.nvim_create_autocmd("WinLeave", {
        group = group,
        callback = function()
            local exit_win = vim.api.nvim_get_current_win()
            if wins[exit_win] then
                M.close_preview_win(exit_win)
                wins[exit_win] = -1
            end
        end,
    })

    vim.api.nvim_create_autocmd("WinResized", {
        group = group,
        callback = function()
            local resized_win = vim.api.nvim_get_current_win()
            local preview_win = wins[resized_win]
            if preview_win and preview_win > 0 then
                M.update_preview_win_pos(preview_win)
            end
        end,
    })
end

--------------------
--- Window Setup ---
--------------------

--- @return QfRancherBorder
local function get_border()
    local g_border = vim.g.qf_rancher_preview_border --- @type QfRancherBorder
    if not g_border then
        local winborder = vim.api.nvim_get_option_value("winborder", { scope = "global" })
        return (winborder and winborder ~= "") and winborder or "single"
    end

    local ey = require("mjm.error-list-types") --- @type QfRancherTypes
    if vim.g.qf_rancher_debug_assertions then
        ey._validate_border(g_border)
    end

    return ey._is_valid_border(g_border) and g_border or "single"
end

local function get_title_pos()
    local g_title = vim.g.qf_rancher_preview_title_pos
    if g_title == "left" or g_title == "center" or g_title == "right" then
        return g_title
    else
        return "left"
    end
end

local function get_siso()
    return vim.g.qf_rancher_preview_use_global_siso
            and vim.api.nvim_get_option_value("siso", { scope = "global" })
        or 6
end

local function get_so()
    return vim.g.qf_rancher_preview_use_global_so
            and vim.api.nvim_get_option_value("so", { scope = "global" })
        or 6
end

local function get_winblend()
    local winblend = vim.g.qf_rancher_preview_winblend
    local valid_winblend = winblend
        and type(winblend) == "number"
        and winblend >= 0
        and winblend <= 100

    return valid_winblend and winblend or 0
end

local function set_preview_winopts(bufnr)
    if not old_bad_preview_win then
        clear_session_data()
        return
    end

    vim.api.nvim_set_option_value("cc", "", { win = old_bad_preview_win })
    vim.api.nvim_set_option_value("cul", true, { win = old_bad_preview_win })

    vim.api.nvim_set_option_value("fdc", "0", { win = old_bad_preview_win })
    vim.api.nvim_set_option_value("fdm", "manual", { win = old_bad_preview_win })

    vim.api.nvim_set_option_value("list", false, { win = old_bad_preview_win })

    vim.api.nvim_set_option_value("nu", true, { win = old_bad_preview_win })
    vim.api.nvim_set_option_value("rnu", false, { win = old_bad_preview_win })
    vim.api.nvim_set_option_value("scl", "no", { win = old_bad_preview_win })

    vim.api.nvim_set_option_value("spell", false, { win = old_bad_preview_win })

    vim.api.nvim_set_option_value("winblend", get_winblend(), { win = old_bad_preview_win })

    vim.api.nvim_set_option_value("so", get_so(), { win = old_bad_preview_win })
    vim.api.nvim_set_option_value("siso", get_siso(), { win = old_bad_preview_win })

    -- TODO: Should not be here
    if vim.g.qf_rancher_preview_show_title then
        local preview_bufname = vim.fn.bufname(bufnr)
        local relative_fname = vim.fn.fnamemodify(preview_bufname, ":.")
        vim.api.nvim_win_set_config(old_bad_preview_win, {
            title = relative_fname,
            title_pos = get_title_pos(),
        })
    end
end

-----------------
--- Buf Setup ---
-----------------

--- @param bufnr integer
--- @param item table
--- @return Range4
local function get_hl_range(bufnr, item)
    local row = item.lnum >= 0 and item.lnum - 1 or 0
    local start_line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
    local start_line_len_0 = math.max(#start_line - 1, 0)
    local col = (function()
        if item.col <= 0 then
            return 0
        end

        -- PR: The documentation says "if true" but it's actually a number value. But double check
        -- the source
        if item.vcol == 1 and old_bad_preview_win then
            -- FUTURE: Might be more accurately handled with a binary search on
            -- vim.fn.strdisplaywidth(). But I have not seen one of these in the wild
            local byte_col = vim.fn.virtcol2col(old_bad_preview_win, item.lnum, item.col)
            return math.max(byte_col - 1, 0)
        end

        return math.min(item.col - 1, start_line_len_0)
    end)()

    local fin_row = item.end_lnum > 0 and item.end_lnum - 1 or row
    local fin_line = fin_row == row and start_line
        or vim.api.nvim_buf_get_lines(bufnr, fin_row, fin_row + 1, false)[1]

    local fin_col = (function()
        if item.end_col <= 0 then
            return #fin_line
        end

        if item.vcol == 1 and old_bad_preview_win then
            -- FUTURE: Might be more accurately handled with a binary search on
            -- vim.fn.strdisplaywidth(). But I have not seen one of these in the wild
            local byte_col = vim.fn.virtcol2col(old_bad_preview_win, item.end_lnum, item.end_col)
            local byte_idx = byte_col - 1
            local utf_idx = vim.str_utfindex(fin_line, "utf-16", byte_idx, false)
            local ex_byte = vim.str_byteindex(fin_line, "utf-16", utf_idx + 1, false)

            return math.max(ex_byte, 0)
        end

        -- Fix diagnostic end_cols. Unsure how this works in other cases
        local end_idx = math.min(item.end_col, #fin_line)
        if not (fin_row == row and end_idx == col + 1) then
            end_idx = math.max(end_idx - 1, 0)
        end

        return end_idx
    end)()

    return { row, col, fin_row, fin_col }
end

local function set_preview_buf_opts(buf)
    vim.api.nvim_set_option_value("buflisted", false, { buf = buf })
    -- Set a non-"" buftype to prevent LSPs from attaching
    vim.api.nvim_set_option_value("buftype", "nowrite", { buf = buf })
    vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
    vim.api.nvim_set_option_value("readonly", true, { buf = buf })
    vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
    vim.api.nvim_set_option_value("undofile", false, { buf = buf })
end

--- @param bufnr integer
--- @return integer|nil
local function get_preview_buf(bufnr)
    if not bufnr then
        return nil
    end

    if bufs[bufnr] then
        return bufs[bufnr]
    end

    local lines = (function()
        if vim.api.nvim_buf_is_loaded(bufnr) then
            return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        end

        local full_path = vim.api.nvim_buf_get_name(bufnr)
        if not vim.uv.fs_access(full_path, 4) then
            return { "Unable to read file " .. full_path }
        end

        -- MAYBE: Add bigfile protection
        return vim.fn.readfile(full_path, "")
    end)() --- @type string[]|nil

    lines = lines or { "Unable to read lines for bufnr " .. bufnr }

    local preview_buf = vim.api.nvim_create_buf(false, false)
    vim.api.nvim_buf_set_lines(preview_buf, 0, 0, false, lines)
    set_preview_buf_opts(preview_buf)

    bufs[bufnr] = preview_buf
    return preview_buf
end

------------------------------
--- Window Opening/Closing ---
------------------------------

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
    }) --- @type table

    local screenrow = vim.fn.screenrow() --- @type integer
    local half_way = e_lines * 0.5 --- @type number
    if screenrow <= half_way then
        return vim.tbl_extend("force", fallback_base, { row = math.floor(e_lines * 0.6) })
    else
        return vim.tbl_extend("force", fallback_base, { row = 0 })
    end
end

--- @return vim.api.keyset.win_config|nil
local function get_win_config()
    if not old_bad_qf_win then
        return nil
    end

    local qf_pos = vim.api.nvim_win_get_position(old_bad_qf_win) --- @type [integer, integer]
    local qf_height = vim.api.nvim_win_get_height(old_bad_qf_win) --- @type integer
    local qf_width = vim.api.nvim_win_get_width(old_bad_qf_win) --- @type integer
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
    local win_cfg = vim.tbl_extend("force", base_cfg, { relative = "win", win = old_bad_qf_win })

    local avail_y_above = math.max(qf_pos[1] - vim_border - 1, 0) --- @type integer
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

    local avail_y_below = e_lines - (qf_pos[1] + qf_height + vim_border + 1) --- @type integer
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
        local y_diff = min_y_space - qf_height
        local half_diff = math.floor(y_diff * 0.5)
        local u_shift = math.max(half_diff - avail_y_above, 0)
        local d_shift = math.max(half_diff - avail_y_below, 0)
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

--- @param preview_win integer
--- @return nil
function M.update_preview_win_pos(preview_win)
    if not vim.api.nvim_win_is_valid(preview_win) then
        local msg = "Preview win " .. preview_win .. " is invalid" --- @type string
        vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
        clear_session_data()
        return
    end

    local win_config = get_win_config()
    if not win_config then
        clear_session_data()
        return
    end

    -- TODO: Something I'm unclear on - Does new config extend on previous? It looks like it does
    vim.api.nvim_win_set_config(preview_win, win_config)
end

--- @param preview_buf integer
--- @param did_ftdetect boolean
--- @param item vim.quickfix.entry
--- @nil
local function decorate_window(preview_buf, did_ftdetect, item)
    local hl_range = get_hl_range(preview_buf, item) --- @type Range4
    if extmarks[preview_buf] then
        vim.api.nvim_buf_del_extmark(preview_buf, hl_ns, extmarks[preview_buf])
        extmarks[preview_buf] = nil
    end

    extmarks[preview_buf] =
        vim.api.nvim_buf_set_extmark(preview_buf, hl_ns, hl_range[1], hl_range[2], {
            hl_group = "QfRancherHighlightItem",
            end_row = hl_range[3],
            end_col = hl_range[4],
            priority = 200,
            strict = false,
        })

    -- NOTE: The preview buf is not associated with a file, so the original bufnr needs to be
    -- passed in for ftdetect and title
    if not did_ftdetect then
        local ft = vim.filetype.match({ buf = item.bufnr }) or "" --- @type string
        vim.api.nvim_set_option_value("filetype", ft, { buf = preview_buf })
    end

    if not old_bad_preview_win then
        clear_session_data()
        return
    end

    --- TODO: Separate the winopts that need to be set every time (title, and whatever else) vs.
    --- the ones that don't
    set_preview_winopts(item.bufnr)
    vim.api.nvim_win_set_cursor(old_bad_preview_win, { item.lnum, item.col - 1 })
    vim.api.nvim_win_call(old_bad_preview_win, function()
        vim.api.nvim_cmd({ cmd = "normal", args = { "zz" }, bang = true }, {})
        vim.api.nvim_cmd({ cmd = "normal", args = { "ze" }, bang = true }, {})
    end)
end

--- @return nil
function M.update_preview_win(preview_win)
    if not (old_bad_preview_win and old_bad_qf_win) then
        clear_session_data()
        return
    end

    local eu = require("mjm.error-list-util") --- @type QfRancherUtils
    local listtype = eu._get_listtype(old_bad_qf_win)
    if not listtype then
        clear_session_data()
        return
    end

    -- TODO: Get and store the loclist info when building the session
    local is_ll = listtype == "loclist"
    -- TODO: Move this over to the tools module
    local cur_list =
        eu._get_getlist({ loclist_source_win = old_bad_qf_win, use_loclist = is_ll })()
    if #cur_list < 1 then
        clear_session_data()
        return
    end

    local line = vim.fn.line(".") --- @type integer
    if line > #cur_list then
        clear_session_data()
        return
    end

    local item = cur_list[line] --- @type vim.quickfix.entry
    local bufnr = item.bufnr --- @type integer
    local preview_buf, did_ftdetect = (function()
        if bufs[bufnr] then
            return bufs[bufnr], true
        else
            return get_preview_buf(bufnr), false
        end
    end)()

    if not preview_buf then
        clear_session_data()
        return
    end

    local win_config = get_win_config() --- @type vim.api.keyset.win_config|nil
    if not win_config then
        clear_session_data()
        return
    end

    vim.api.nvim_win_set_config(old_bad_preview_win, win_config)
    vim.api.nvim_win_set_buf(old_bad_preview_win, preview_buf)
    decorate_window(preview_buf, did_ftdetect, item)
end

function M.open_preview_win()
    if old_bad_preview_win then
        return
    end

    --- TODO: Some general confusion in this function and others
    --- The first thing we should do is see if there's a session and build the info from it
    --- Why are we potentially creating a session each time?

    local eu = require("mjm.error-list-util") --- @type QfRancherUtils
    local cur_win = vim.api.nvim_get_current_win() --- @type integer
    if not eu._win_is_list(cur_win) then
        clear_session_data()
        return
    end

    local is_ll = listtype == "loclist"
    -- TODO: not sure output opts is correct here but can look
    local cur_list =
        eu._get_getlist({ loclist_source_win = old_bad_qf_win, use_loclist = is_ll })()
    if #cur_list < 1 then
        return
    end

    local line = vim.fn.line(".")
    if line > #cur_list then
        clear_session_data()
        return
    end

    create_autocmds()

    local bufnr = item.bufnr
    local preview_buf = bufs[bufnr]
    local did_ftdetect = true
    if not preview_buf then
        did_ftdetect = false
        preview_buf = get_preview_buf(bufnr)
    end

    if not preview_buf then
        clear_session_data()
        return
    end

    local win_config = get_win_config()
    if not win_config then
        clear_session_data()
        return
    end

    old_bad_preview_win = vim.api.nvim_open_win(preview_buf, false, win_config)
    decorate_window(preview_buf, did_ftdetect, item)
end

--- @param qf_win integer
--- @return nil
function M.close_preview_win(qf_win)
    if vim.g.qf_rancher_debug_assertions then
        -- Since we need only need qf_win for cache access, don't bother checking win validity
        vim.validate("qf_win", qf_win, "number")
    end

    if not old_bad_preview_win then
        return
    end

    local preview_win = wins[qf_win]
    if preview_win and vim.api.nvim_win_is_valid(preview_win) then
        vim.api.nvim_win_close(preview_win, true)
    end
end

function M.toggle_preview_win()
    if old_bad_preview_win then
        M.close_preview_win()
    else
        M.open_preview_win()
    end
end

return M

------------
--- TODO ---
------------

--- Move protected win close to the utils file and use it here
--- Do a Grok audit on this module when complete. It's self-contained enough that it should work

--- - Check that all functions have reasonable default sorts
--- - Check that window height updates are triggered where appropriate
--- - Check that functions have proper visibility
--- - Check that all mappings have plugs and cmds
--- - Check that all maps/cmds/plugs have desc fieldss
--- - Check that all functions have annotations and documentation
--- - Check that the qf and loclist versions are both properly built for purpose. Should be able
---     to use the loclist function for buf/win specific info
---
--- TODO: It should be possible to customize the kind of marking for the actual qf text
--- - Use cursor column to show column
--- - Use visual mode highlighting of the row
--- TODO: The highlight should be toggleable
--- TODO: The number line should show by default, but be toggleable

--- FUTURE: Should be possible to scroll the preview window. See
--- https://github.com/bfrg/vim-qf-preview for relevant controls

--- CREDITS:
--- - https://github.com/r0nsha/qfpreview.nvim
