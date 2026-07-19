local api = vim.api
local fn = vim.fn

local matcher = require("farsight._match")
local ntt = require("nvim-tools.table")

--------------------------
-- MARK: Hl and Ns Info --
--------------------------

local ns_basename = "farsight.static"
local state_ns_dims = {} ---@type uinteger[]
local state_ns_dynamics = {} ---@type uinteger[]

---@param idx uinteger
---@return uinteger
local function state_ns_dim_get_at(idx)
    local state_ns_dims_len = #state_ns_dims
    if state_ns_dims_len >= idx then
        return state_ns_dims[idx]
    end

    local diff = idx - state_ns_dims_len
    for _ = 1, diff do
        local ns_num = #state_ns_dims + 1
        local new_name = ns_basename .. ".dim." .. tostring(ns_num)
        state_ns_dims[ns_num] = api.nvim_create_namespace(new_name)
    end

    return state_ns_dims[idx]
end

---@param idx uinteger
---@return uinteger
local function state_ns_dynamic_get_at(idx)
    local state_ns_dynamics_len = #state_ns_dynamics
    if state_ns_dynamics_len >= idx then
        return state_ns_dynamics[idx]
    end

    local diff = idx - state_ns_dynamics_len
    for _ = 1, diff do
        local ns_num = #state_ns_dynamics + 1
        local new_name = ns_basename .. ".dynamic." .. tostring(ns_num)
        state_ns_dynamics[ns_num] = api.nvim_create_namespace(new_name)
    end

    return state_ns_dynamics[idx]
end

local hl_error = api.nvim_get_hl_id_by_name("ErrorMsg")

local hl_dim = api.nvim_get_hl_id_by_name("farsightStaticDim")
local hl_label = api.nvim_get_hl_id_by_name("farsightStaticLabel")
local hl_target = api.nvim_get_hl_id_by_name("farsightStaticTargetLabel")

local hl_priority_dim = vim.hl.priorities.user + 50
local hl_priority_label = hl_priority_dim + 1

---@param win_matches table<uinteger, farsight.static.MatchData>
local function win_matches_ns_set(win_matches)
    for win, matches in pairs(win_matches) do
        api.nvim__ns_set(matches.ns_dynamic, { wins = { win } })
    end
end

---@param win_matches table<uinteger, farsight.static.MatchData>
---@param dim boolean
local function namespaces_dim_clear(win_matches, dim)
    if not dim then
        return
    end

    for _, matches in pairs(win_matches) do
        api.nvim_buf_clear_namespace(matches.buf, matches.ns_dim, 0, -1)
    end
end

---@param win_matches table<uinteger, farsight.static.MatchData>
local function win_matches_clear_ns_dynamic(win_matches)
    for _, matches in pairs(win_matches) do
        api.nvim_buf_clear_namespace(matches.buf, matches.ns_dynamic, 0, -1)
    end
end

--------------------------
-- MARK: Jump Execution --
--------------------------

---@param win uinteger
---@param buf uinteger
---@param row uinteger
---@param col uinteger
---@param cur_win uinteger
---@param ctx farsight.static.MatchCtx
local function do_jump(win, buf, row, col, cur_win, ctx)
    if cur_win ~= win then
        api.nvim_set_current_win(win)
    else
        row, col = require("farsight._util").ensure_state_for_omode(win, buf, row, col)
    end

    if not ctx.keepjumps then
        api.nvim_cmd({ cmd = "norm", args = { "m'" }, bang = true }, {})
    end

    ---@cast col uinteger
    local pos = { row, col }
    require("nvim-tools.pos").ext_to_mark_pos(pos)
    api.nvim_win_set_cursor(win, pos)
    local unfold = ctx.unfold
    if unfold ~= "" then
        api.nvim_cmd({ cmd = "norm", args = { unfold }, bang = true }, {})
    end

    ctx.on_jump(win, buf, pos)
end
-- TODO-DEP: After csearch is done, consolidate their jump logic.

---@param win_matches table<uinteger, farsight.static.MatchData>
---@return boolean, uinteger, uinteger, uinteger
---Extmark indexed (0-based).
local function matches_find_jump_target(win_matches)
    local has_any_targets = false
    local win = -1
    local row = -1
    local col = -1

    for match_win, matches in pairs(win_matches) do
        local targets = matches.targets
        if #targets > 1 then
            return true, -1, -1, -1
        end

        if #targets == 1 then
            if win > 1000 or row > -1 or col > -1 then
                return true, -1, -1, -1
            end

            has_any_targets = true
            win = match_win
            row = targets[1][1]
            col = targets[1][2]
        end
    end

    return has_any_targets, win, row, col
end

---@param win_matches table<uinteger, farsight.static.MatchData> Modified in place!
local function matches_vtext_clear(win_matches)
    for _, matches in pairs(win_matches) do
        for _, target in ipairs(matches.targets) do
            ntt.i_clear(target[4])
        end
    end
end

---@param win_matches table<uinteger, farsight.static.MatchData> Modified in place!
---@param label_start_idx uinteger
---@param input string
local function win_matches_filter_targets(win_matches, label_start_idx, input)
    for _, matches in pairs(win_matches) do
        ntt.i_keep(matches.targets, function(target)
            return target[3][label_start_idx] == input
        end)
    end
end

---@param win_matches table<uinteger, farsight.static.MatchData>
local function extmarks_vtext_set(win_matches)
    ---@type vim.api.keyset.set_extmark
    local extmark_opts = {
        hl_mode = "combine",
        priority = hl_priority_label,
        virt_text_pos = "overlay",
        strict = false,
    }

    for _, matches in pairs(win_matches) do
        local buf = matches.buf
        local ns = matches.ns_dynamic
        local targets = matches.targets
        for _, target in ipairs(targets) do
            extmark_opts.virt_text = target[4]
            api.nvim_buf_set_extmark(buf, ns, target[1], target[2], extmark_opts)
        end
    end
end

---@param label string[]
---@param vtext [string, uinteger|string][]
---@param max_len integer
---@param start_idx integer
local function vtext_add(label, vtext, max_len, start_idx)
    local len_label = #label
    local len_display = len_label - start_idx + 1
    if len_display == 1 then
        vtext[1] = { label[start_idx], hl_target }
    elseif len_display <= max_len then
        local len_most = len_label - 1
        vtext[1] = { table.concat(label, "", start_idx, len_most), hl_label }
        vtext[2] = { label[len_label], hl_target }
    else
        local concat_end = start_idx + max_len - 1
        vtext[1] = { table.concat(label, "", start_idx, concat_end), hl_label }
    end
end

---@param win_matches table<uinteger, farsight.static.MatchData> Modified in place!
---@param start_idx uinteger
local function win_matches_vtexts_add(win_matches, start_idx)
    local v_maxcol = vim.v.maxcol
    for _, matches in pairs(win_matches) do
        local targets = matches.targets
        if #targets > 0 then
            ntt.i_modify_adjacent(targets, function(ta, tb)
                local max_len = ta[1] == tb[1] and (tb[2] - ta[2]) or v_maxcol - ta[2]
                vtext_add(ta[3], ta[4], max_len, start_idx)
                return ta, tb
            end)

            local last = targets[#targets]
            local last_max = v_maxcol - last[2]
            vtext_add(last[3], last[4], last_max, start_idx)
        end
    end
end

---@param win_matches table<uinteger, farsight.static.MatchData>
---@return boolean, uinteger, uinteger, uinteger
local function jump_pos_get_from_prompt(win_matches)
    local label_start_idx = 1
    while true do
        win_matches_vtexts_add(win_matches, label_start_idx)
        extmarks_vtext_set(win_matches)
        api.nvim__redraw({ flush = true, valid = true })

        local _, input = pcall(fn.getcharstr)
        win_matches_clear_ns_dynamic(win_matches)

        win_matches_filter_targets(win_matches, label_start_idx, input)
        local ok, win, row, col = matches_find_jump_target(win_matches)
        if (not ok) or (win >= 1000 and row > -1 and col > -1) then
            api.nvim__redraw({ flush = false, valid = true })
            return ok, win, row, col
        end

        matches_vtext_clear(win_matches)
        label_start_idx = label_start_idx + 1
    end
end

----------------------
-- MARK: Jump Setup --
----------------------

-- ---@param win_matches table<uinteger, farsight.static.MatchData>
-- ---@param dim boolean
-- local function win_matches_extmarks_dim_set(win_matches, dim)
--     if not dim then
--         return
--     end
--
--     ---@type vim.api.keyset.set_extmark
--     local extmark_opts = {
--         hl_group = hl_dim,
--         priority = hl_priority_dim,
--         strict = false,
--     }
--
--     -- We go through the trouble of setting the dim highlights by line because Neovim does not
--     -- consistently draw multi-line highlight extmarks only within namespace window scope.
--     for _, matches in pairs(win_matches) do
--         local match_range = matches.match_range
--         for i = match_range[1], match_range[3] do
--             extmark_opts.end_row = i + 1
--             api.nvim_buf_set_extmark(matches.buf, matches.ns_dim, i, 0, extmark_opts)
--         end
--     end
-- end

---@param win_matches table<uinteger, farsight.static.MatchData>
---@param dim boolean
local function win_matches_extmarks_dim_set(win_matches, dim)
    if not dim then
        return
    end

    local dim_extmarks_set_checked = require("farsight._util").dim_set_ns_and_extmarks
    for win, matches in pairs(win_matches) do
        local ns = matches.ns_dim
        local match_range = matches.match_range
        local buf = matches.buf
        dim_extmarks_set_checked(ns, win, hl_dim, hl_priority_dim, match_range, buf)
    end
end

---@param labels string[][] Modified in place!
---@param start uinteger
---@param stop uinteger
---@param tokens string[]
local function labels_populate(labels, start, stop, tokens)
    local range_len = stop - start + 1
    local tokens_len = #tokens
    if range_len == 0 or tokens_len <= 1 then
        return
    end

    local quotient = math.floor(range_len / tokens_len)
    local remainder = range_len % tokens_len

    local token_idx = 1
    local token_start = start
    local to_place = quotient
    if remainder > 0 then
        to_place = to_place + 1
        remainder = remainder - 1
    end

    for i = start, stop do
        local label = labels[i]
        label[#label + 1] = tokens[token_idx]
        to_place = to_place - 1
        if to_place == 0 then
            if token_start < i then
                labels_populate(labels, token_start, i, tokens)
            end

            token_idx = token_idx + 1
            token_start = i + 1
            to_place = quotient
            if remainder > 0 then
                to_place = to_place + 1
                ---@cast remainder uinteger
                remainder = remainder - 1
            end
        end
    end
end

---@param win_matches table<uinteger, farsight.static.MatchData> Modified in place!
---@param wins uinteger[] Assumes proper ordering.
---@param tokens string[]
local function win_targets_labels_add(win_matches, wins, tokens)
    -- TODO-DEP: When cutting off, remove limit from the util.
    local total_targets = ntt.fold(win_matches, 0, function(total, _, matches)
        return total + #matches.targets
    end)

    local j = 1
    local all_labels = ntt.new(total_targets, 0) ---@type string[][]
    for _, win in ipairs(wins) do
        for _, target in ipairs(win_matches[win].targets) do
            all_labels[j] = target[3]
            j = j + 1
        end
    end

    ---@diagnostic disable-next-line: call-non-callable
    assert(#all_labels == total_targets)
    labels_populate(all_labels, 1, total_targets, tokens)
end

-----------------------
-- MARK: Get Matches --
-----------------------

-- Assumes that we are only doing aware position in single-window scenarios.
---@param pos_name string
---@param ranges [uinteger, uinteger, uinteger, uinteger][]
---@return uinteger
local function bisected_idx_get(pos_name, ranges)
    local pos = fn.getpos(pos_name)
    local row = pos[2] - 1
    local col_1 = pos[3]
    local pos_range = { row, col_1 - 1, row, col_1 }
    local idx = vim.list.bisect(ranges, pos_range, {
        key = function(range)
            local cmp_res = require("nvim-tools.range").cmp_(range, pos_range)
            if cmp_res == -2 or cmp_res == -1 then
                return -1
            elseif cmp_res == 1 or cmp_res == 2 then
                return 1
            else
                return 0
            end
        end,
    })

    ---@cast idx uinteger
    return idx - 1
end
-- TODO: Same logic as doc_hl jumping. Outline to catharsis or nvim-tools.

---@param ctx farsight.static.MatchCtx
---@param ranges [uinteger, uinteger, uinteger, uinteger][]
---@return uinteger
local function split_point_get(ctx, ranges)
    local mode = ctx.mode
    local ntm = require("nvim-tools.misc")
    if ctx.vmode_aware and ntm.is_vmode(mode) then
        return bisected_idx_get("v", ranges)
    elseif ctx.omode_aware and ntm.is_omode(mode) then
        return bisected_idx_get(".", ranges)
    else
        return ctx.label_start and #ranges or 0
    end
end

---@class farsight.static.Target
---@field [1] uinteger
---@field [2] uinteger
---@field [3] string[]
---@field [4] [string, string|uinteger][]

---@class farsight.static.MatchData
---@field buf uinteger
---@field match_range [uinteger, uinteger, uinteger, uinteger]
---@field ns_dim uinteger
---@field ns_dynamic uinteger
---@field targets farsight.static.Target[]

---@param ctx farsight.static.MatchCtx
---@param win uinteger
---@param idx uinteger Assumes that ns_ensure has been run for the relevant indexes.
---@return uinteger, farsight.static.MatchData
local function match_data_mapper(ctx, win, idx)
    local buf = api.nvim_win_get_buf(win)
    local match_range, ranges, lines = matcher.static_ranges_get(win, buf, ctx.regex, ctx.folds)

    local start_end = split_point_get(ctx, ranges)
    local start_ranges, end_ranges = ntt.i_split_at(ranges, start_end)
    local targets = ntt.i_filter_map_to(start_ranges, function(range)
        return { range[1], range[2], {}, {} }
    end)

    local targets_end = ntt.i_filter_map_to(end_ranges, function(range)
        local end_row = range[3]
        local end_col = range[4]
        local diff = vim.str_utf_start(lines[end_row], end_col)
        return { end_row, end_col - 1 - diff, {}, {} }
    end)

    return win,
        {
            buf = buf,
            match_range = match_range,
            ns_dim = state_ns_dim_get_at(idx),
            ns_dynamic = state_ns_dynamic_get_at(idx),
            targets = ntt.i_append(targets, targets_end),
        }
end

---@param mode string
---@param cur_win uinteger
---@return uinteger[]
local function wins_valid_sorted_get(mode, cur_win)
    local ntm = require("nvim-tools.misc")
    local wins = (ntm.is_vmode(mode) or ntm.is_omode(mode)) and { cur_win }
        or api.nvim_tabpage_list_wins(0)

    local _, positions = ntt.i_filter_modify_accum(wins, {}, function(pos_acc, win)
        local config = api.nvim_win_get_config(win)
        if config.focusable and not config.hide then
            local pos = api.nvim_win_get_position(win)
            pos_acc[win] = { pos[1], pos[2], config.zindex or 0 }
            return pos_acc, win
        end

        return pos_acc, nil
    end)

    ---@cast positions table<uinteger, { [1]:integer, [2]:integer, [3]:integer }>
    table.sort(wins, function(a, b)
        local pos_a = positions[a]
        local pos_b = positions[b]
        if pos_a[3] < pos_b[3] then
            return true
        elseif pos_a[3] > pos_b[3] then
            return false
        elseif pos_a[2] < pos_b[2] then
            return true
        elseif pos_a[2] > pos_b[2] then
            return false
        else
            return pos_a[1] < pos_b[1]
        end
    end)

    return wins
end

local M = {}

---@class farsight.static.MatchCtx : farsight.static.Ctx
---@field mode string
---@field regex vim.regex

---@param cur_win uinteger
---@param ctx farsight.static.Ctx
function M.static(cur_win, ctx)
    local mode = api.nvim_get_mode().mode
    local wins = wins_valid_sorted_get(mode, cur_win)
    local wins_len = #wins
    if wins_len == 0 then
        api.nvim_echo({ { "No visible, focusable wins", hl_error } }, false, {})
        return
    end

    ---@cast ctx farsight.static.MatchCtx
    ctx.mode = mode
    ctx.regex = vim.regex(ctx.pattern) -- Hard erroring is fine if this fails.
    -- TODO-DEP: When this is cut off, remove the filtering + limit functionality here. Both hurt
    -- JIT compilation.
    local win_matches = ntt.i_filter_map_ctx_to_dict(wins, ctx, match_data_mapper)
    ---@cast win_matches table<uinteger, farsight.static.MatchData>

    local ok, win, row, col = matches_find_jump_target(win_matches)
    if not ok then
        api.nvim_echo({ { "No targets", "" } }, false, {})
        return
    elseif win >= 1000 and row > -1 and col > -1 then
        do_jump(win, win_matches[win].buf, row, col, cur_win, ctx)
        return
    end

    win_targets_labels_add(win_matches, wins, ctx.tokens)
    local dim = ctx.dim
    win_matches_ns_set(win_matches)
    win_matches_extmarks_dim_set(win_matches, dim)
    ok, win, row, col = jump_pos_get_from_prompt(win_matches)
    namespaces_dim_clear(win_matches, dim)
    if (not ok) or win < 1000 or row < 0 or col < 0 then
        return
    end

    do_jump(win, win_matches[win].buf, row, col, cur_win, ctx)
end

return M
