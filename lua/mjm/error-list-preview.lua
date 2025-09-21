--- TODO: Go through this and determine what should be exposed, "private exposed", and private

--- FUTURE: Should be possible to scroll the preview window. See
--- https://github.com/bfrg/vim-qf-preview for relevant controls

--- CREDITS:
--- - https://github.com/r0nsha/qfpreview.nvim

local M = {}

--------------
--- Config ---
--------------

local hl_ns = vim.api.nvim_create_namespace("qf-rancher-preview-hl")

-- DOCUMENT: This highlight group
local hl_name = "QfRancherHighlightItem"
local cur_hl = vim.api.nvim_get_hl(0, { name = hl_name })
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

local augroup_name = "qf-rancher-preview-group"
local augroup = vim.api.nvim_create_augroup(augroup_name, { clear = true })

local preview_win = nil
local buf_cache = {}
local extmark_cache = {}
local qf_buf = nil
local qf_win = nil

-------------------------
--- Session Functions ---
-------------------------

local function clear_session_data()
    if preview_win and vim.api.nvim_win_is_valid(preview_win) then
        local ok_w, result = pcall(function()
            vim.api.nvim_win_close(preview_win, true)
        end)

        if not ok_w then
            local msg = result or "Unknown error closing preview win"
            vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
        end
    end

    for bufnr, extmark in pairs(extmark_cache) do
        if vim.api.nvim_buf_is_valid(bufnr) then
            vim.api.nvim_buf_del_extmark(bufnr, hl_ns, extmark)
        end
    end

    for _, bufnr in pairs(buf_cache) do
        if vim.api.nvim_buf_is_valid(bufnr) then
            vim.api.nvim_buf_delete(bufnr, { force = true })
        end
    end

    preview_win = nil
    buf_cache = {}
    extmark_cache = {}
    qf_buf = nil
    qf_win = nil

    local autocmds = vim.api.nvim_get_autocmds({ group = augroup })
    for _, a in pairs(autocmds) do
        vim.api.nvim_del_autocmd(a.id)
    end
end

local function create_autocmds()
    vim.api.nvim_create_autocmd("CursorMoved", {
        group = augroup,
        callback = function()
            local cur_win = vim.api.nvim_get_current_win()
            if cur_win == qf_win then
                M._update_win()
            end
        end,
    })

    vim.api.nvim_create_autocmd("BufEnter", {
        group = augroup,
        callback = function(ev)
            local cur_win = vim.api.nvim_get_current_win()
            if cur_win == qf_win and ev.buf ~= qf_buf then
                clear_session_data()
            end
        end,
    })

    vim.api.nvim_create_autocmd("WinClosed", {
        group = augroup,
        callback = function(ev)
            if tonumber(ev.match) == qf_win then
                clear_session_data()
            end
        end,
    })

    vim.api.nvim_create_autocmd("WinEnter", {
        group = augroup,
        callback = function()
            local cur_win = vim.api.nvim_get_current_win()
            if cur_win ~= qf_win then
                M.close_preview_win()
            end
        end,
    })

    vim.api.nvim_create_autocmd("WinLeave", {
        group = augroup,
        callback = function()
            local cur_win = vim.api.nvim_get_current_win()
            if cur_win == qf_win then
                M.close_preview_win()
            end
        end,
    })

    vim.api.nvim_create_autocmd("WinResized", {
        group = augroup,
        callback = function()
            if preview_win then
                M.update_preview_win_pos()
            end
        end,
    })
end

--- @return boolean
local function create_preview_session(win)
    if qf_win then
        return true
    end

    local cur_win = win or vim.api.nvim_get_current_win()
    local listtype = require("mjm.error-list-util").get_listtype(cur_win)
    if not listtype then
        return false
    end

    qf_win = cur_win
    qf_buf = vim.api.nvim_win_get_buf(qf_win)
    create_autocmds()
    return true
end

--------------------
--- Window Setup ---
--------------------

-- :h 'winborder'
-- PR: This feels like something you could put into vim.validate
local valid_borders = { "bold", "double", "none", "rounded", "shadow", "single", "solid" }
local function get_border()
    local ok, g_border = pcall(vim.api.nvim_get_var, "qf_rancher_preview_border")
    if not ok then
        local winborder = vim.api.nvim_get_option_value("winborder", { scope = "global" })
        if winborder ~= "" then
            return winborder
        end

        return "single"
    end

    local g_type = type(g_border)
    if g_type == "string" and vim.tbl_contains(valid_borders, g_border) then
        return g_border
    end

    if not g_type == "table" then
        return "single"
    end

    if #g_border ~= 8 then
        return "single"
    end

    for _, segment in pairs(g_border) do
        if type(segment) ~= "string" then
            return "single"
        end
    end

    return g_border
end

local function get_title_pos()
    local ok, g_title = pcall(vim.api.nvim_get_var, "qf_rancher_preview_title_pos")
    if ok and g_title == "left" or g_title == "center" or g_title == "right" then
        return g_title
    end

    return "left"
end

local function should_show_title()
    local ok, g_title = pcall(vim.api.nvim_get_var, "qf_rancher_preview_show_title")
    if ok and g_title == false then
        return false
    else
        return true
    end
end

local function get_siso()
    local ok, use_siso = pcall(vim.api.nvim_get_var, "qf_rancher_preview_use_global_siso")
    if ok and type(use_siso) == "boolean" and use_siso == true then
        return vim.api.nvim_get_option_value("siso", { scope = "global" })
    else
        return 6
    end
end

local function get_so()
    local ok, use_so = pcall(vim.api.nvim_get_var, "qf_rancher_preview_use_global_so")
    if ok and type(use_so) == "boolean" and use_so == true then
        return vim.api.nvim_get_option_value("so", { scope = "global" })
    else
        return 6
    end
end

local function get_winblend()
    local ok, winblend = pcall(vim.api.nvim_get_var, "qf_rancher_preview_winblend")
    local valid_winblend = ok
        and winblend
        and type(winblend) == "number"
        and winblend >= 0
        and winblend <= 100

    return valid_winblend and winblend or 0
end

local function set_preview_winopts(bufnr)
    if not preview_win then
        clear_session_data()
        return
    end

    vim.api.nvim_set_option_value("cc", "", { win = preview_win })
    vim.api.nvim_set_option_value("cul", true, { win = preview_win })

    vim.api.nvim_set_option_value("fdc", "0", { win = preview_win })
    vim.api.nvim_set_option_value("fdm", "manual", { win = preview_win })

    vim.api.nvim_set_option_value("list", false, { win = preview_win })

    vim.api.nvim_set_option_value("nu", true, { win = preview_win })
    vim.api.nvim_set_option_value("rnu", false, { win = preview_win })
    vim.api.nvim_set_option_value("scl", "no", { win = preview_win })

    vim.api.nvim_set_option_value("spell", false, { win = preview_win })

    vim.api.nvim_set_option_value("winblend", get_winblend(), { win = preview_win })

    vim.api.nvim_set_option_value("so", get_so(), { win = preview_win })
    vim.api.nvim_set_option_value("siso", get_siso(), { win = preview_win })

    if should_show_title() then
        local preview_bufname = vim.fn.bufname(bufnr)
        local relative_fname = vim.fn.fnamemodify(preview_bufname, ":.")
        vim.api.nvim_win_set_config(preview_win, {
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
        if item.vcol == 1 and preview_win then
            -- FUTURE: Might be more accurately handled with a binary search on
            -- vim.fn.strdisplaywidth(). But I have not seen one of these in the wild
            local byte_col = vim.fn.virtcol2col(preview_win, item.lnum, item.col)
            return math.max(byte_col - 1, 0)
        end

        return math.min(item.col - 1, start_line_len_0)
    end)()

    local fin_row = item.end_lnum > 0 and item.end_lnum - 1 or row
    local fin_line = (function()
        if fin_row ~= row then
            return vim.api.nvim_buf_get_lines(bufnr, fin_row, fin_row + 1, false)[1]
        else
            return start_line
        end
    end)()

    local fin_col = (function()
        if item.end_col <= 0 then
            return #fin_line
        end

        if item.vcol == 1 and preview_win then
            -- FUTURE: Might be more accurately handled with a binary search on
            -- vim.fn.strdisplaywidth(). But I have not seen one of these in the wild
            local byte_col = vim.fn.virtcol2col(preview_win, item.end_lnum, item.end_col)
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

    if buf_cache[bufnr] then
        return buf_cache[bufnr]
    end

    local lines = (function()
        if vim.api.nvim_buf_is_loaded(bufnr) then
            return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        end

        local bufname = vim.fn.bufname(bufnr)
        local full_path = vim.fn.fnamemodify(bufname, ":p")
        if not vim.fn.filereadable(full_path) then
            return { "Unable to read file " .. full_path }
        end

        -- MAYBE: Add bigfile protection
        return vim.fn.readfile(full_path, "")
    end)() --- @type string[]|nil

    lines = lines or { "Unable to read lines for bufnr " .. bufnr }

    local preview_buf = vim.api.nvim_create_buf(false, false)
    vim.api.nvim_buf_set_lines(preview_buf, 0, 0, false, lines)
    set_preview_buf_opts(preview_buf)

    buf_cache[bufnr] = preview_buf
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

--- @return table|nil
local function get_win_config()
    if not qf_win then
        return nil
    end

    local qf_pos = vim.api.nvim_win_get_position(qf_win)
    local qf_height = vim.api.nvim_win_get_height(qf_win)
    local qf_width = vim.api.nvim_win_get_width(qf_win)
    local e_lines = vim.api.nvim_get_option_value("lines", { scope = "global" })
    local e_cols = vim.api.nvim_get_option_value("columns", { scope = "global" })

    local border = get_border()
    local preview_border_width = border ~= "none" and 2 or 0
    local vim_border = 1
    local padding = 1

    -- Window width and height only account for the inside of the window, not its borders. For
    -- consistency, track the target internal size of the window separately from the space needed
    -- to render the window plus the borders and padding
    local min_height = 6
    local min_y_space = min_height + preview_border_width
    local max_height = 24
    -- MAYBE: For left/right previews, no padding on top looks better. Same for below previews
    -- For top previews, can go either way on padding. Would be neat to have more fine-grain
    -- control. But for now, just say no vertical padding for consistency
    local min_width = 79
    local min_x_space = min_width + (padding * 2) + preview_border_width

    local base_cfg = { border = border, focusable = false }
    local win_cfg = vim.tbl_extend("force", base_cfg, { relative = "win", win = qf_win })

    local avail_y_above = math.max(qf_pos[1] - vim_border - 1, 0)
    -- If space is available to the left or right, the vim border has to be there
    local avail_x_left = math.max(qf_pos[2] - vim_border, 0)
    local avail_x_right = math.max(e_cols - (qf_pos[2] + qf_width + vim_border), 0)
    local avail_width = qf_width - (padding * 2) - preview_border_width
    local avail_e_width = e_cols - (padding * 2) - preview_border_width

    local function cfg_vert_spill(height, row)
        local x_diff = min_x_space - qf_width
        local half_diff = math.ceil(x_diff * 0.5)
        local r_shift = math.max(half_diff - avail_x_left, 0)
        local l_shift = math.max(half_diff - avail_x_right, 0)
        return vim.tbl_extend("force", win_cfg, {
            height = height,
            row = row,
            width = math.min(min_width, avail_e_width),
            col = (half_diff * -1) + r_shift - l_shift + 1,
        })
    end

    -- Design note: Prefer rendering previews with spill into other wins to keep the direction
    -- they appear as consistent as possible
    if avail_y_above >= min_y_space then
        local height = avail_y_above - preview_border_width
        height = math.min(height, max_height)
        local row = (height + preview_border_width + vim_border) * -1
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

    local avail_y_below = e_lines - (qf_pos[1] + qf_height + vim_border + 1)
    if avail_y_below >= min_y_space then
        local height = avail_y_below - preview_border_width
        height = math.min(height, max_height)
        local row = qf_height + vim_border
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

    local avail_height = qf_height - (padding * 2) - preview_border_width
    local avail_e_lines = e_lines - preview_border_width
    local side_height = math.min(avail_height, max_height)
    local function cfg_hor_spill(width, col)
        local y_diff = min_y_space - qf_height
        local half_diff = math.floor(y_diff * 0.5)
        local u_shift = math.max(half_diff - avail_y_above, 0)
        local d_shift = math.max(half_diff - avail_y_below, 0)
        return vim.tbl_extend("force", win_cfg, {
            height = math.min(min_height, avail_e_lines),
            row = (half_diff * -1) - u_shift + d_shift - 1,
            width = width,
            col = col,
        })
    end

    local function open_left()
        local col = (qf_pos[2] - vim_border) * -1
        local width = avail_x_left - (padding * 2) - preview_border_width
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
        local col = qf_pos[2] + qf_width + vim_border + padding
        local width = avail_x_right - (padding * 2) - preview_border_width
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

function M.update_preview_win_pos()
    if not preview_win then
        clear_session_data()
        return
    end

    local win_config = get_win_config()
    if not win_config then
        clear_session_data()
        return
    end

    vim.api.nvim_win_set_config(preview_win, win_config)
end

local function decorate_window(preview_buf, did_ftdetect, item)
    local hl_range = get_hl_range(preview_buf, item)
    if extmark_cache[preview_buf] then
        vim.api.nvim_buf_del_extmark(preview_buf, hl_ns, extmark_cache[preview_buf])
        extmark_cache[preview_buf] = nil
    end

    extmark_cache[preview_buf] =
        vim.api.nvim_buf_set_extmark(preview_buf, hl_ns, hl_range[1], hl_range[2], {
            hl_group = "QfRancherHighlightItem",
            end_row = hl_range[3],
            end_col = hl_range[4],
            priority = 200,
            strict = false,
        })

    -- NOTE: The preview buf is not associated with a file, so the original bufnr needs to be
    -- passed in for ftdetect and tite
    if not did_ftdetect then
        local ft = vim.filetype.match({ buf = item.bufnr })
        vim.api.nvim_set_option_value("filetype", ft, { buf = preview_buf })
    end

    if not preview_win then
        clear_session_data()
        return
    end

    -- PERF: It's not necessary to set all of these winopts every time the window is updated,
    -- but it is also robust and I am not seeing a perf cost from doing so
    set_preview_winopts(item.bufnr)
    vim.api.nvim_win_set_cursor(preview_win, { item.lnum, item.col - 1 })
    vim.api.nvim_win_call(preview_win, function()
        vim.api.nvim_cmd({ cmd = "normal", args = { "zz" }, bang = true }, {})
        vim.api.nvim_cmd({ cmd = "normal", args = { "ze" }, bang = true }, {})
    end)
end

function M._update_win()
    if not (preview_win and qf_win) then
        clear_session_data()
        return
    end

    local listtype = require("mjm.error-list-util").get_listtype(qf_win)
    if not listtype then
        clear_session_data()
        return
    end

    local is_loclist = listtype == "loclist"
    local cur_list = require("mjm.error-list-util").get_win_getlist(qf_win, is_loclist)()
    if #cur_list < 1 then
        clear_session_data()
        return
    end

    local line = vim.fn.line(".")
    if line > #cur_list then
        clear_session_data()
        return
    end

    local item = cur_list[line]
    local bufnr = item.bufnr
    local preview_buf, did_ftdetect = (function()
        if buf_cache[bufnr] then
            return buf_cache[bufnr], true
        else
            return get_preview_buf(bufnr), false
        end
    end)()

    if not preview_buf then
        clear_session_data()
        return
    end

    local win_config = get_win_config()
    if not win_config then
        clear_session_data()
        return
    end

    vim.api.nvim_win_set_config(preview_win, win_config)
    vim.api.nvim_win_set_buf(preview_win, preview_buf)
    decorate_window(preview_buf, did_ftdetect, item)
end

function M.open_preview_win()
    if preview_win then
        return
    end

    local cur_win = vim.api.nvim_get_current_win()
    local listtype = require("mjm.error-list-util").get_listtype(cur_win)
    if not listtype then
        clear_session_data()
        return
    end

    local is_loclist = listtype == "loclist"
    local cur_list = require("mjm.error-list-util").get_win_getlist(qf_win, is_loclist)()
    if #cur_list < 1 then
        return
    end

    local line = vim.fn.line(".")
    if line > #cur_list then
        clear_session_data()
        return
    end

    local item = cur_list[line]
    if not create_preview_session(cur_win) then
        return
    end

    local bufnr = item.bufnr
    local preview_buf = buf_cache[bufnr]
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

    preview_win = vim.api.nvim_open_win(preview_buf, false, win_config)
    decorate_window(preview_buf, did_ftdetect, item)
end

function M.close_preview_win()
    if not preview_win then
        return
    end

    if vim.api.nvim_win_is_valid(preview_win) then
        vim.api.nvim_win_close(preview_win, true)
    end

    preview_win = nil
end

function M.toggle_preview_win()
    if preview_win then
        M.close_preview_win()
    else
        M.open_preview_win()
    end
end

return M
