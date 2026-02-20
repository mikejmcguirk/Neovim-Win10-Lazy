local api = vim.api
local fn = vim.fn

---@class farsight.csearch.TokenLabels
---@field [1] integer Length
---@field [2] integer[] Rows (zero indexed)
---@field [3] integer[] Cols
---@field [4] integer[] End cols
---@field [5] integer[] Hl group IDs

local MAX_MAX_TOKENS = 3
local DEFAULT_MAX_TOKENS = MAX_MAX_TOKENS
assert(DEFAULT_MAX_TOKENS <= MAX_MAX_TOKENS)

local HL_1ST_STR = "FarsightCsearch1st"
local HL_2ND_STR = "FarsightCsearch2nd"
local HL_3RD_STR = "FarsightCsearch3rd"
local HL_DIM_STR = "FarsightCsearchDim"

local hl_ns = api.nvim_create_namespace("FarsightCsearch")
api.nvim_set_hl(0, HL_1ST_STR, { default = true, link = "DiffChange" })
api.nvim_set_hl(0, HL_2ND_STR, { default = true, link = "DiffText" })
api.nvim_set_hl(0, HL_3RD_STR, { default = true, link = "DiffAdd" })
api.nvim_set_hl(0, HL_DIM_STR, { default = true, link = "Comment" })

local hl_1st = api.nvim_get_hl_id_by_name(HL_1ST_STR)
local hl_2nd = api.nvim_get_hl_id_by_name(HL_2ND_STR)
local hl_3rd = api.nvim_get_hl_id_by_name(HL_3RD_STR)
local hl_dim = api.nvim_get_hl_id_by_name(HL_DIM_STR)
local hl_map = { hl_1st, hl_2nd, hl_3rd } ---@type integer[]
assert(#hl_map == MAX_MAX_TOKENS)

local get_utf_codepoint = require("farsight._util_char")._get_utf_codepoint
local maxcol = vim.v.maxcol
local str_byte = string.byte

local on_key_repeating = 0 ---@type 0|1
local function get_repeat_state()
    return on_key_repeating
end

local function setup_repeat_tracking()
    local has_ffi, ffi = pcall(require, "ffi")
    if has_ffi then
        -- Dot repeats move their text from the repeat buffer to the stuff buffer for execution.
        -- When chars are processed from that buffer, the KeyStuffed global is set to 1.
        -- searchc in search.c checks this value for redoing state.
        if pcall(ffi.cdef, "int KeyStuffed;") then
            get_repeat_state = function()
                return ffi.C.KeyStuffed --[[@as 0|1]]
            end

            return
        end
    end

    -- Credit folke/flash
    vim.on_key(function(key)
        if key == "." and fn.reg_executing() == "" and fn.reg_recording() == "" then
            on_key_repeating = 1
            vim.schedule(function()
                on_key_repeating = 0
            end)
        end
    end)
end

setup_repeat_tracking()

---@param char string
---@param is_omode boolean
---@param forward 0|1
---@param opts_until 0|1
---@return string
local function get_pattern(char, is_omode, forward, opts_until)
    ---@type string
    local selection = api.nvim_get_option_value("selection", { scope = "global" })
    local pattern = string.gsub(char, "\\", "\\\\")

    if forward == 1 then
        if opts_until == 1 then
            if is_omode and selection == "exclusive" then
                return "\\C\\V" .. pattern
            else
                return "\\C\\m.\\ze\\V" .. pattern
            end
        else
            if is_omode and selection == "exclusive" then
                return "\\C\\V" .. pattern .. "\\zs\\m."
            else
                return "\\C\\V" .. pattern
            end
        end
    end

    if opts_until == 1 then
        return "\\C\\V" .. pattern .. "\\zs\\m."
    else
        return "\\C\\V" .. pattern
    end
end

---@param win integer
---@param buf integer
---@param cur_pos { [1]: integer, [2]: integer }
---@param char string
---@param opts farsight.csearch.CsearchOpts
local function do_csearch(win, buf, cur_pos, char, opts)
    local ut = require("farsight.util")
    local is_omode = ut._resolve_map_mode(api.nvim_get_mode().mode) == "o"
    local pattern = get_pattern(char, is_omode, opts.forward, opts["until"])

    local flags_tbl = { "Wn" }
    flags_tbl[#flags_tbl + 1] = opts.forward == 1 and "z" or "b"
    if opts["until"] == 1 and not opts.until_skip then
        flags_tbl[#flags_tbl + 1] = "c"
    end

    local flags = table.concat(flags_tbl, "")
    local stop_row = opts.single_line == true and cur_pos[1] or 0

    local count = vim.v.count1
    local fn_line = fn.line
    local foldclosed = fn.foldclosed
    local skip_folds = opts.skip_folds

    -- FUTURE: https://github.com/neovim/neovim/pull/37872
    ---@type { [1]: integer, [2]: integer, [3]: integer? }
    local jump_pos = fn.searchpos(pattern, flags, stop_row, 2000, function()
        local search_row = fn_line(".")
        local fold_row = foldclosed(search_row)
        if fold_row == -1 or (skip_folds == false and fold_row == search_row) then
            count = count - 1
            if count == 0 then
                return 0
            end
        end

        return 1
    end)

    if jump_pos[1] == 0 and jump_pos[2] == 0 then
        return
    end

    if jump_pos[1] ~= cur_pos[1] and not opts.keepjumps and not is_omode then
        api.nvim_cmd({ cmd = "norm", args = { "m'" }, bang = true }, {})
    end

    ---@type string
    local selection = api.nvim_get_option_value("selection", { scope = "global" })
    -- If operating backward, the cursor character should not be affected
    if opts.forward == 0 and is_omode and selection ~= "exclusive" then
        fn.searchpos("\\m.", "Wb", cur_pos[1])
    end

    if is_omode then
        api.nvim_cmd({ cmd = "norm", args = { "v" }, bang = true }, {})
    end

    -- searchpos() returns are 1, 1 indexed
    jump_pos[2] = math.max(jump_pos[2] - 1, 0)
    api.nvim_win_set_cursor(win, jump_pos)
    opts.on_jump(win, buf, jump_pos)
end

---@param win integer
---@param buf integer
---@param show_hl boolean
---@param valid boolean
local function checked_clear_hl(win, buf, show_hl, valid)
    if not show_hl then
        return
    end

    pcall(api.nvim_buf_clear_namespace, buf, hl_ns, 0, -1)
    if valid == false then
        api.nvim__redraw({ win = win, valid = valid })
    end
end

---@param buf integer
---@param label_len integer
---@param label_rows integer[]
local function dim_target_lines(buf, label_len, label_rows)
    local rows = {} ---@type table<integer, boolean>
    for i = 1, label_len do
        rows[label_rows[i]] = true
    end

    local nvim_buf_set_extmark = api.nvim_buf_set_extmark
    local dim_extmark_opts = {
        end_col = 0,
        hl_eol = true,
        hl_group = hl_dim,
        priority = 999,
    }

    for row, _ in pairs(rows) do
        dim_extmark_opts.end_line = row + 1
        pcall(nvim_buf_set_extmark, buf, hl_ns, row, 0, dim_extmark_opts)
    end
end

---@param buf integer
---@param labels farsight.csearch.TokenLabels
local function do_highlights(buf, labels)
    local extmark_opts = { priority = 1000 } ---@type vim.api.keyset.set_extmark
    local len_labels = labels[1]
    local l_rows = labels[2]
    local l_cols = labels[3]
    local l_end_cols = labels[4]
    local l_hl_ids = labels[5]

    for i = 1, len_labels do
        extmark_opts.hl_group = l_hl_ids[i]
        extmark_opts.end_col = l_end_cols[i]
        pcall(api.nvim_buf_set_extmark, buf, hl_ns, l_rows[i], l_cols[i], extmark_opts)
    end
end

---@param row_0 integer
---@param col_1 integer
---@param len_char integer
---@param count integer
---@param labels farsight.csearch.TokenLabels
local function add_label(row_0, col_1, len_char, count, labels)
    local new_label_len = labels[1] + 1

    labels[1] = new_label_len
    labels[2][new_label_len] = row_0
    local col_0 = col_1 - 1
    labels[3][new_label_len] = col_0
    labels[4][new_label_len] = col_0 + len_char
    labels[5][new_label_len] = hl_map[count]
end

---Edits counts and labels in place
---Start is one indexed, inclusive
---@param row_0 integer
---@param line string
---@param init integer
---@param locator fun(codepoint: integer):boolean
---@param counts table<integer, integer>
---@param min_count integer
---@param max_count integer
---@param labels farsight.csearch.TokenLabels
local function add_all_labels_rev(row_0, line, init, locator, counts, min_count, max_count, labels)
    local i = init
    while i >= 1 do
        local b1 = str_byte(line, i)
        if b1 <= 0x80 or b1 >= 0xC0 then
            local char_nr, len_char = get_utf_codepoint(line, b1, i)
            if locator(char_nr) then
                local char_count = counts[char_nr] or min_count
                if char_count < max_count then
                    local new_count = char_count + 1
                    counts[char_nr] = new_count

                    if new_count > 0 then
                        local col_0 = i - 1
                        add_label(row_0, col_0, len_char, new_count, labels)
                    end
                end
            end
        end

        i = i - 1
    end
end

---Edits counts and labels in place
---Init is one indexed, inclusive
---@param row_0 integer
---@param line string
---@param init integer
---@param locator fun(codepoint: integer):boolean
---@param counts table<integer, integer>
---@param min_count integer
---@param max_count integer
---@param labels farsight.csearch.TokenLabels
local function add_labels_rev(row_0, line, init, locator, counts, min_count, max_count, labels)
    local hl_col_1 = -1
    local hl_char_len = -1
    local hl_count = maxcol

    local i = init
    while i >= 1 do
        local b1 = str_byte(line, i)
        if b1 <= 0x80 or b1 >= 0xC0 then
            local char_nr, len_char = get_utf_codepoint(line, b1, i)
            if locator(char_nr) then
                local char_count = counts[char_nr] or min_count
                if char_count < max_count then
                    local new_count = char_count + 1
                    counts[char_nr] = new_count

                    if new_count >= 1 and new_count <= hl_count then
                        hl_col_1 = i
                        hl_char_len = len_char
                        hl_count = new_count
                    end
                end
            else
                if hl_count <= max_count then
                    add_label(row_0, hl_col_1, hl_char_len, hl_count, labels)
                    hl_col_1 = -1
                    hl_char_len = -1
                    hl_count = maxcol
                end
            end
        end

        i = i - 1
    end

    if hl_count > max_count then
        return
    end

    add_label(row_0, hl_col_1, hl_char_len, hl_count, labels)
end

---Edits counts and labels in place
---Init is one indexed, inclusive
---@param row_0 integer
---@param line string
---@param init integer
---@param locator fun(codepoint: integer):boolean
---@param counts table<integer, integer>
---@param min_count integer
---@param max_count integer
---@param labels farsight.csearch.TokenLabels
local function add_all_labels_fwd(row_0, line, init, locator, counts, min_count, max_count, labels)
    local i = init
    local len_line = #line
    while i <= len_line do
        local char_nr, len_char = get_utf_codepoint(line, str_byte(line, i), i)
        if locator(char_nr) then
            local char_count = counts[char_nr] or min_count
            if char_count < max_count then
                local new_count = char_count + 1
                counts[char_nr] = new_count

                if new_count > 0 then
                    local col_0 = i - 1
                    add_label(row_0, col_0, len_char, new_count, labels)
                end
            end
        end

        i = i + len_char
    end
end

---Edits counts and labels in place
---Init is one indexed, inclusive
---@param row_0 integer
---@param line string
---@param init integer
---@param locator fun(codepoint: integer):boolean
---@param counts table<integer, integer>
---@param min_count integer
---@param max_count integer
---@param labels farsight.csearch.TokenLabels
local function add_labels_fwd(row_0, line, init, locator, counts, min_count, max_count, labels)
    local hl_col_1 = -1
    local hl_char_len = -1
    local hl_count = maxcol

    local i = init
    local len_line = #line
    while i <= len_line do
        local char_nr, len_char = get_utf_codepoint(line, str_byte(line, i), i)
        if locator(char_nr) then
            local char_count = counts[char_nr] or min_count
            if char_count < max_count then
                local new_count = char_count + 1
                counts[char_nr] = new_count

                if new_count > 0 and new_count < hl_count then
                    hl_col_1 = i
                    hl_char_len = len_char
                    hl_count = new_count
                end
            end
        else
            if hl_count <= max_count then
                add_label(row_0, hl_col_1, hl_char_len, hl_count, labels)
                hl_col_1 = -1
                hl_char_len = -1
                hl_count = maxcol
            end
        end

        i = i + len_char
    end

    if hl_count > max_count then
        return
    end

    add_label(row_0, hl_col_1, hl_char_len, hl_count, labels)
end

---Edits labels in place
---@param buf integer
---@param cur_pos { [1]: integer, [2]: integer }
---@param iterator function
---@param labels farsight.csearch.TokenLabels
---@param opts farsight.csearch.CsearchOpts
---@return boolean
local function get_labels_rev(buf, cur_pos, iterator, labels, opts)
    local row = cur_pos[1]
    local col = cur_pos[2]

    local counts = {} ---@type table<integer, integer>
    local min_count = 1 - vim.v.count1
    local top = fn.line("w0")
    local lines = api.nvim_buf_get_lines(buf, top - 1, row, false)

    local foldclosed = fn.foldclosed
    local locator = opts.locator
    local max_tokens = opts.max_tokens
    local skip_folds = opts.skip_folds

    local offset = top - 1
    local last_fold_row = foldclosed(row)
    if last_fold_row == -1 or (skip_folds == false and last_fold_row == row) then
        local row_0 = row - 1
        local cur_idx = row - offset
        iterator(row_0, lines[cur_idx], col, locator, counts, min_count, max_tokens, labels)
    end

    if opts.single_line == true then
        return true
    end

    for i = math.max(row - 1, 1), top, -1 do
        local fold_row = foldclosed(i)
        if fold_row == -1 or (skip_folds == false and fold_row == i) then
            local row_0 = i - 1
            local line = lines[i - offset]
            iterator(row_0, line, #line, locator, counts, min_count, max_tokens, labels)
        end
    end

    return true
end

---Edits labels in place
---@param buf integer
---@param cur_pos { [1]: integer, [2]: integer }
---@param iterator function
---@param labels farsight.csearch.TokenLabels
---@param opts farsight.csearch.CsearchOpts
---@return boolean
local function get_labels_fwd(buf, cur_pos, iterator, labels, opts)
    local row = cur_pos[1]
    local col = cur_pos[2]

    local counts = {} ---@type table<integer, integer>
    local min_count = 1 - vim.v.count1
    local bot = fn.line("w$")
    local lines = api.nvim_buf_get_lines(buf, row - 1, bot, false)

    local foldclosed = fn.foldclosed
    local locator = opts.locator
    local max_tokens = opts.max_tokens
    local skip_folds = opts.skip_folds

    local first_fold_row = foldclosed(row)
    if first_fold_row == -1 or (skip_folds == false and first_fold_row == row) then
        local row_0 = row - 1
        local line = lines[1]
        iterator(row_0, line, col + 2, locator, counts, min_count, max_tokens, labels)
    end

    if opts.single_line == true then
        return true
    end

    local offset = row - 1
    for i = row + 1, bot do
        local fold_row = foldclosed(i)
        if fold_row == -1 or (skip_folds == false and fold_row == i) then
            local row_0 = i - 1
            local line = lines[i - offset]
            iterator(row_0, line, 1, locator, counts, min_count, max_tokens, labels)
        end
    end

    if not api.nvim_get_option_value("wrap", { win = 0 }) then
        return true
    end

    local fill_row = math.min(bot + 1, api.nvim_buf_line_count(buf))
    if row == bot then
        return true
    end

    local first_spos = fn.screenpos(0, fill_row, 1)
    if first_spos.row < 1 then
        return true
    end

    local old_len_labels = labels[1]
    local fill_fold_row = foldclosed(fill_row)
    if fill_fold_row == -1 or (skip_folds == false and fill_fold_row == fill_row) then
        local fill_line = api.nvim_buf_get_lines(buf, fill_row - 1, fill_row, false)[1]
        iterator(row, fill_line, 1, locator, counts, min_count, max_tokens, labels)
    end

    if labels[1] > old_len_labels then
        return false
    else
        return true
    end
end

---@param win integer
---@param buf integer
---@param cur_pos { [1]: integer, [2]: integer }
---@param opts farsight.csearch.CsearchOpts
---@return boolean
local function checked_show_hl(win, buf, cur_pos, opts)
    if opts.show_hl == false then
        return true
    end

    if fn.reg_executing() ~= "" then
        opts.show_hl = false
        return true
    end

    ---@type farsight.csearch.TokenLabels
    local labels = {
        0,
        require("farsight.util")._table_new(256, 0),
        require("farsight.util")._table_new(256, 0),
        require("farsight.util")._table_new(256, 0),
        require("farsight.util")._table_new(256, 0),
    }

    local valid
    if opts.forward == 1 then
        local iterator = opts.all_tokens and add_all_labels_fwd or add_labels_fwd
        valid = get_labels_fwd(buf, cur_pos, iterator, labels, opts)
    else
        local iterator = opts.all_tokens and add_all_labels_rev or add_labels_rev
        valid = get_labels_rev(buf, cur_pos, iterator, labels, opts)
    end

    if labels[1] > 0 then
        api.nvim__ns_set(hl_ns, { wins = { win } })
        do_highlights(buf, labels)
        if opts.dim then
            dim_target_lines(buf, labels[1], labels[2])
        end

        api.nvim__redraw({ win = win, valid = valid })
    end

    return valid
end

---Must put opts in a state such that:
---- All values are present
---- All internal tables are deep copied
---@param opts farsight.csearch.CsearchOpts
---@param cur_buf integer
local function resolve_base_opts(opts, cur_buf)
    vim.validate("opts", opts, "table")
    local ut = require("farsight.util")

    if opts.forward == nil then
        opts.forward = 1
    else
        vim.validate("opts.forward", opts.forward, function()
            return opts.forward == 0 or opts.forward == 1
        end, "opts.forward must be 0 or 1")
    end

    opts.keepjumps = ut._use_gb_if_nil(opts.keepjumps, "farsight_csearch_keepjumps", cur_buf)
    opts.keepjumps = ut._resolve_bool_opt(opts.keepjumps, false)

    opts.on_jump = ut._use_gb_if_nil(opts.on_jump, "farsight_csearch_on_jump", cur_buf)
    if opts.on_jump == nil then
        opts.on_jump = function()
            ---@type string
            local fdo = api.nvim_get_option_value("fdo", { scope = "global" })
            local all, _, _ = string.find(fdo, "all", 1, true)
            local hor, _, _ = string.find(fdo, "hor", 1, true)
            if all or hor then
                api.nvim_cmd({ cmd = "norm", args = { "zv" }, bang = true }, {})
            end
        end
    else
        vim.validate("opts.on_jump", opts.on_jump, "callable")
    end

    opts.single_line = ut._use_gb_if_nil(opts.single_line, "farsight_csearch_single_line", cur_buf)
    opts.single_line = ut._resolve_bool_opt(opts.single_line, false)

    opts.skip_folds = ut._use_gb_if_nil(opts.skip_folds, "farsight_csearch_skip_folds", cur_buf)
    opts.skip_folds = ut._resolve_bool_opt(opts.skip_folds, false)
end

---Must put opts in a state such that:
---- All values are present
---- All internal tables are deep copied
---@param opts farsight.csearch.CsearchOpts
---@param cur_buf integer
local function resolve_csearch_opts(opts, cur_buf)
    resolve_base_opts(opts, cur_buf)
    local ut = require("farsight.util")

    opts.all_tokens = ut._use_gb_if_nil(opts.all_tokens, "farsight_csearch_all_tokens", cur_buf)
    opts.all_tokens = ut._resolve_bool_opt(opts.all_tokens, false)

    opts.dim = ut._use_gb_if_nil(opts.dim, "farsight_csearch_dim", cur_buf)
    opts.dim = ut._resolve_bool_opt(opts.dim, false)

    opts.locator = ut._use_gb_if_nil(opts.locator, "farsight_csearch_locator", cur_buf)
    if opts.locator == nil then
        local isk = api.nvim_get_option_value("isk", { buf = cur_buf }) ---@type string
        local isk_tbl = require("farsight._util_char")._parse_isk(cur_buf, isk)
        opts.locator = function(byte)
            return isk_tbl[byte + 1] == true
        end
    else
        vim.validate("opts.locator", opts.locator, "callable")
    end

    local gb_max_tokens = "farsight_csearch_max_tokens"
    opts.max_tokens = ut._use_gb_if_nil(opts.max_tokens, gb_max_tokens, cur_buf)
    if opts.max_tokens == nil then
        opts.max_tokens = DEFAULT_MAX_TOKENS
    else
        vim.validate("opts.max_tokens", opts.max_tokens, ut._is_uint)
        opts.max_tokens = math.min(opts.max_tokens, MAX_MAX_TOKENS)
    end

    opts.show_hl = ut._use_gb_if_nil(opts.show_hl, "farsight_csearch_show_hl", cur_buf)
    opts.show_hl = ut._resolve_bool_opt(opts.show_hl, true)

    if opts["until"] == nil then
        opts["until"] = 0
    else
        vim.validate("opts.until", opts["until"], function()
            return opts["until"] == 0 or opts["until"] == 1
        end, "opts.until must be 0 or 1")
    end

    opts.until_skip = false
end

---@class farsight.Csearch
local Csearch = {}

---Opts set for both new character searches and repeat commands
---@class farsight.csearch.BaseOpts
---`1` search forward, `0` to search backward. (Default: `1`)
---@field forward? 0|1
---If true, limit searches to a single line (Default: `false`. Searches will
---traverse the entire buffer)
---@field single_line? boolean
---If true, disregard fold lines (Default: `false`. The first line of closed
---folds will be searched)
---@field skip_folds? boolean
---Disable setting jump marks. (Default: `false`. If a search traverses
---multiple lines, a jump mark will be set)
---@field keepjumps? boolean
---Callback to execute on successful jump. (Default: Check the |foldopen|
---option for `all` or `hor`. If found, perform a |zv| command)
---@field on_jump? fun(win: integer, buf: integer, pos: { [1]: integer, [2]: integer })
---@field package until_skip? boolean

---Opts for new searches
---@class farsight.csearch.CsearchOpts : farsight.csearch.BaseOpts
---When `1`, search until just before the selected character (|t| and |T|
---behavior). (Default: `0`, or |f| and |F| behavior)
---@field until? 0|1
---Highlight characters to indicate if they are the first, second, or third
---occurence from the cursor. (Default: `true`)
---@field show_hl? boolean
---Function to determine which characters should be highlighted. The
---function parameter is a UTF-8 code point.
---
---Example:
---
---Target alpha characters:
--->
---  function(codepoint)
---      return (codepoint >= 0x41 and codepoint <= 0x5A) or
---          (codepoint >= 0x61 and codepoint <= 0x7A)
---  end
---<
---
---Combine with all_tokens = `false` to target whitespace delimited |WORD|s:
--->
---  function(codepoint)
---      return codepoint ~= 0x20 and codepoint ~= 0x09 and codepoint ~= 0x0
---          and codepoint ~= 0xA0
---  end
---<
---
---(Default: characters are compared against the value of |iskeyword|)
---@field locator? fun(codepoint: integer):boolean
---If `true`, show all characters targeted by the locator function. If `false`,
---one highlight is shown per contiguous group of targeted characters. The
---shorted possible jump path per group is shown.
---(Default: false. In combination with the default locator, this means one
---token is displayed per keyword)
---@field all_tokens? boolean
---Dim lines with targeted characters (Default: `false`)
---@field dim? boolean
---Maximum amount of highlights to show per targetable character. Max `3`.
---(Default: `3`)
---@field max_tokens? integer

---Perform a single character search from user input. Similar to |f|, |F|, |t|,
---and |T|. Will not prompt during a |single-repeat| or |macro|.
---@param opts? farsight.csearch.CsearchOpts
function Csearch.csearch(opts)
    opts = opts and vim.deepcopy(opts) or {}
    local cur_win = api.nvim_get_current_win()
    local cur_buf = api.nvim_win_get_buf(cur_win)
    resolve_csearch_opts(opts, cur_buf)

    local char = nil
    -- Only get once, since Nvim's internal state has no guarantees
    local is_repeating = get_repeat_state()
    if is_repeating == 1 then
        char = fn.getcharsearch().char
        if char == "" then
            return
        end
    end

    local cur_pos = api.nvim_win_get_cursor(cur_win)
    if not char then
        local valid = checked_show_hl(cur_win, cur_buf, cur_pos, opts)
        _, char = pcall(fn.getcharstr, -1)
        checked_clear_hl(cur_win, cur_buf, opts.show_hl, valid)
    end

    if is_repeating == 0 then
        fn.setcharsearch({
            char = char,
            forward = opts.forward,
            ["until"] = opts["until"],
        })
    end

    -- Default f/t updates charsearch on unsuccessful searches, so wait until now for this check
    if opts.forward == 0 and cur_pos[1] == 1 and cur_pos[2] == 0 then
        return
    end

    do_csearch(cur_win, cur_buf, cur_pos, char, opts)
end

---Repeat the last character search. Similar to |;| and |,|.
---This function respects the |cpoptions| ";" flag
---@param opts? farsight.csearch.BaseOpts
function Csearch.rep(opts)
    opts = opts and vim.deepcopy(opts) or {} --[[ @as farsight.csearch.CsearchOpts ]]
    local cur_win = api.nvim_get_current_win()
    local cur_buf = api.nvim_win_get_buf(cur_win)
    resolve_base_opts(opts, cur_buf)

    local charsearch = fn.getcharsearch()
    local char = charsearch.char
    if char == "" then
        return
    end

    opts["until"] = charsearch["until"]
    local cpo = api.nvim_get_option_value("cpo", { scope = "global" }) ---@type string
    local cpo_noskip, _, _ = string.find(cpo, ";", 1, true)
    if cpo_noskip == nil then
        opts.until_skip = true
    else
        opts.until_skip = false
    end

    opts.forward = require("bit").bxor(opts.forward, charsearch.forward, 1)
    local cur_pos = api.nvim_win_get_cursor(cur_win)
    do_csearch(cur_win, cur_buf, cur_pos, char, opts)
end

return Csearch

-- TODO: For my personal purposes, do I want to use isprint instead of isk? Too noisy as a default.
-- Raise broader question though - What if a user does want to do this? Are the functions exposed
-- that allow them to do this?
-- TODO: Rename parse_isk to parse_isopt so it's useful with isprint. Make a public interface
-- for it

-- MID: Fold ideas:
-- - Display the foldclosed line as virtual text with token highlights
--   - How to dim?
--   - By default, the line should still be highlighted like a fold
-- - Display relevant tokens at the beginning like jump does
-- Same ideas could be applied to jump

-- LOW: Could default size the label arrays as 512 if one of the following conditions are met:
-- - keymap ~= ""
-- - arabic == true
-- - rightleft == true
-- - termbidi == true
-- - ambiwidth == double

-- PR: It would be cool if Neovim provided some kind of clear_plugin_highlights function that
-- plugins could register with. That way, devs/users wouldn't have to create bespoke highlight
-- clearing for every plugin
-- PR: It should be natively possible to detect if you are in the middle of a dot repeat.

-- NON: Allowing max_tokens > 3. This would result in more than four keypresses to get to a
-- location. The other Farsight modules can get you anywhere in four or less
-- NON: Multi-window. Significant complexity add/perf loss for little practical value
-- NON: Persistent highlighting. Creates code complexity/error surface area. Pushes  repeatedly
-- pressing ;/, instead of using jumps
-- NON: Ignorecase/smartcase support. Breaks the data model. Does not map 1:1 with what's shown
-- in the buffer
