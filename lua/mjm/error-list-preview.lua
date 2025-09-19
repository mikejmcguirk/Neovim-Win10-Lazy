--- Credits:
--- - https://github.com/r0nsha/qfpreview.nvim

local M = {}

-- TODO: Need to know where qf win is relative to other windows so we can open win in proper place
-- TODO: Need to handle resizing the qf win
--- TODO: the window size should be set relative to the current list. there's the horizontal/
--- vertical/top/bottom issue, but also the width. If the list (qf) takes up the whole width,
--- the preview should also get the full width. For smaller lists, smaller previews
--- TEST: For super small windows, what happens with scrolloff? Can Nvim resolve scrolloff values
--- that are too small?

-----------------------------
--- r0nsha qfpreview code ---
-----------------------------

-- ---@param qfwin number
-- ---@return number,number
-- local function get_aligned_col_width(qfwin)
--   local has_border = vim.o.winborder ~= "none"
--   local col = vim.api.nvim_win_get_position(qfwin)[2]
--   local width = vim.api.nvim_win_get_width(qfwin)
--
--   if not has_border then
--     return col, width
--   end
--
--   if (col + width) == vim.o.columns then
--     return col + 1, width - 1
--   elseif col == 0 then
--     return col, width - 1
--   else
--     return col - 1, width
--   end
-- end

-- NOTE: statusline compensation
-- ---@param qfwin number
-- ---@return vim.api.keyset.win_config
-- function Preview:win_config(qfwin)
--   local has_border = vim.o.winborder ~= "none"
--   local border_width = has_border and 2 or 0
--   local col, width = get_aligned_col_width(qfwin)
--
--   if self.config.ui.height == "fill" then
--     local statusline_height = vim.o.laststatus == 0 and 0 or 1
--     local height = vim.o.lines - vim.api.nvim_win_get_height(qfwin) - vim.o.cmdheight - border_width - statusline_height
--
--     if height < 0 then
--       height = 15
--     end
--
--     return {
--       relative = "editor",
--       width = width,
--       height = height,
--       row = 0,
--       col = col,
--       focusable = false,
--     }
--   end
--
--   local height = self.config.ui.height or 15
--
--   return {
--     relative = "win",
--     win = vim.api.nvim_get_current_win(),
--     width = width,
--     height = height,
--     row = -1 * height - border_width,
--     col = col,
--     focusable = false,
--   }
-- end

-------------------------
--- bqf preview stuff ---
-------------------------

--- TODO: Need to handle relative position of Qf to Nvim boundaries
-- https://github.com/kevinhwang91/nvim-bqf/blob/main/lua/bqf/preview/floatwin.lua
-- Lots of position resolution in here
--- https://github.com/kevinhwang91/nvim-bqf/blob/main/lua/bqf/preview/handler.lua

--------------
--- Config ---
--------------

-- TODO: Allow for customizing as many of the winopts as possible. Stuff like winblend
-- TODO: The autocmd for this should resolve in the "plugin" file. I don't see the need for the
-- autocmd to run if it does nothing
vim.api.nvim_set_var("qf_rancher_preview_autoshow", false)
-- vim.api.nvim_set_var("qf_rancher_preview_border", "single")
-- vim.api.nvim_set_var("qf_rancher_preview_hl_group", "IncSearch")
vim.api.nvim_set_var("qf_rancher_preview_show_title", false)
-- vim.api.nvim_set_var("qf_rancher_preview_title_pos", "center")
vim.api.nvim_set_var("qf_rancher_preview_use_global_so", false)
vim.api.nvim_set_var("qf_rancher_preview_use_global_siso", false)

---------------------
--- Session State ---
---------------------

local hl_ns = vim.api.nvim_create_namespace("qf-rancher-preview-hl")

local preview_win = nil
local buf_cache = {}
local qf_buf = nil
local qf_win = nil

vim.keymap.set("n", "<leader><leader>", function()
    print(vim.inspect(buf_cache))
end)

local augroup_name = "qf-rancher-preview-group"
local augroup = vim.api.nvim_create_augroup(augroup_name, { clear = true })

-------------------------
--- Session Functions ---
-------------------------

local function clear_session_data()
    for _, bufnr in pairs(buf_cache) do
        if vim.api.nvim_buf_is_valid(bufnr) then
            vim.api.nvim_buf_clear_namespace(bufnr, hl_ns, 0, -1)
            vim.api.nvim_buf_delete(bufnr, { force = true })
        end
    end

    preview_win = nil
    buf_cache = {}
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
                -- TODO: I think this is firing when I'm leaving the qflist
                clear_session_data()
            end
        end,
    })

    vim.api.nvim_create_autocmd("WinClosed", {
        group = augroup,
        callback = function()
            local cur_win = vim.api.nvim_get_current_win()
            if cur_win == qf_win then
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

local function set_preview_winopts(bufnr)
    if not preview_win then
        clear_session_data()
        return
    end

    vim.api.nvim_set_option_value("cul", true, { win = preview_win })

    vim.api.nvim_set_option_value("fdc", "0", { win = preview_win })
    vim.api.nvim_set_option_value("fdm", "manual", { win = preview_win })

    vim.api.nvim_set_option_value("list", false, { win = preview_win })

    vim.api.nvim_set_option_value("nu", true, { win = preview_win })
    vim.api.nvim_set_option_value("rnu", false, { win = preview_win })
    vim.api.nvim_set_option_value("scl", "no", { win = preview_win })

    vim.api.nvim_set_option_value("spell", false, { win = preview_win })

    vim.api.nvim_set_option_value("winblend", 0, { win = preview_win })

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
-- TODO: This needs to handle the virtual column case in addition to the byte col case
local function get_hl_range(bufnr, item)
    local row = item.lnum >= 0 and item.lnum - 1 or 0
    local start_line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
    local col = item.col > 0 and item.col - 1 or 0

    local fin_row = item.end_lnum > 0 and item.end_lnum - 1 or row
    local fin_line = (function()
        if fin_row ~= row then
            return vim.api.nvim_buf_get_lines(bufnr, fin_row, fin_row + 1, false)
        else
            return start_line
        end
    end)()

    local fin_col = item.end_col > 0 and item.end_col - 1 or #fin_line

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

local function win_position()
    --- TODO: Open strategy:
    --- - Check in order: top, bottom, right, left
    --- - If the direction can be used at all, use it
    --- - Try to fit if possible
    --- - If no fits are possible, use half-fill based on screenpos
    --- - The dimensions/spacing I have right now are the target. The one-padding IMO helps with
    --- numberline confusion, and the height is enough to breathe a bit while still feeling
    --- compact. The min width IMO is 79. Anything else is unreadable. Unsure yet about
    --- min height. Thinking like five but need to do observations. So if you can fit the
    --- minimum in a direction, use the minimum. Remember though that the calculations need to
    --- account for the border. I *think* the win config does that but need to test with no
    --- border
    if not qf_win then
        return
    end

    local win_pos = vim.api.nvim_win_get_position(qf_win)
    local win_height = vim.api.nvim_win_get_height(qf_win)
    local win_width = vim.api.nvim_win_get_width(qf_win)
    local lines = vim.api.nvim_get_option_value("lines", { scope = "global" })
    local columns = vim.api.nvim_get_option_value("columns", { scope = "global" })
end

local function get_hl_group()
    local default_hl = "CurSearch"
    local ok_g, g_hl = pcall(vim.api.nvim_get_var, "qf_rancher_preview_hl_group")
    if not ok_g then
        return default_hl
    end

    local hl_group = (function()
        if type(g_hl) == "string" then
            return vim.api.nvim_get_hl(0, { name = g_hl })
        elseif type(g_hl) == "number" then
            return vim.api.nvim_get_hl(0, { id = g_hl })
        end
    end)()

    if (not hl_group) or #vim.tbl_keys(hl_group) == 0 then
        return default_hl
    else
        return g_hl
    end
end

-- TODO: bad naming
local function decorate_window(preview_buf, did_ftdetect, item)
    local hl_range = get_hl_range(preview_buf, item)
    vim.api.nvim_buf_clear_namespace(preview_buf, hl_ns, 0, -1)
    local hl_group = get_hl_group()
    vim.hl.range(
        preview_buf,
        hl_ns,
        hl_group,
        { hl_range[1], hl_range[2] },
        { hl_range[3], hl_range[4] },
        {}
    )

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
    -- NOTE: The preview buf is not associated with a file, so the original bufnr needs to be
    -- passed in to get the bufname for titles
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
    local cur_list = require("mjm.error-list-util").get_getlist(is_loclist, qf_win)()
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
    local cur_list = require("mjm.error-list-util").get_getlist(is_loclist, qf_win)()
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

    win_position()

    local win_config = {
        border = get_border(),
        relative = "win",
        win = qf_win,
        height = 24,
        width = 102,
        row = -28,
        col = 1,
        focusable = false,
    }

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
