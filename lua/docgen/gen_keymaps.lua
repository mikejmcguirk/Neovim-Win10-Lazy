local const = require("docgen.const")
local TEXT_WIDTH = const.TEXT_WIDTH
local TAB_WIDTH = const.TAB_WIDTH

local DESC_INDENT = TAB_WIDTH * 2
local LUA_WIDTH = 99
local MAP_WIDTH = TEXT_WIDTH - TAB_WIDTH
local SET = "vim.api.nvim_set_keymap("

local util = require("docgen.util")
local checked_surround = util.checked_surround
local err_if_seen_or_add = util.err_if_seen_or_add
-- local list_copy = util.list_copy
local list_flat_map_to = util.list_flat_map_to
local list_filter_map = util.list_filter_map
local list_filter_map_accum = util.list_filter_map_accum
local list_filter_map_to = util.list_filter_map_to
local list_fold = util.list_fold
local list_insert_at = util.list_insert_at
local mode_map_to_short = util.mode_map_to_short
local tag_from_txt = util.tag_from_txt
local wrap = util.wrap

---@class docgen.keymap.Map
---@field callback_txt? string
---@field desc string
---@field desc_short string
---@field lhs string[]
---@field modes string[]
---@field opts vim.api.keyset.keymap
---@field plugs string[]
---@field rhs? string
---@field tags_addtl string[]

local M = {}

---Errors if resulting plug map is > 50 bytes.
---@param help_prefix string
---@param plug_txt string
---@return string
local function plug_txt_to_map(help_prefix, plug_txt)
    local plug_fmt = "<Plug>(" .. help_prefix .. "-" .. plug_txt .. ")"
    if #plug_fmt > 50 then
        error(plug_fmt .. " is > 50 bytes long")
    end

    return plug_fmt
end

---@param maps docgen.keymap.Map[]
---@param help_prefix string
---@return string
function M.gen_keymap_vimdoc(maps, help_prefix)
    -- TODO: vim.validate help_prefix

    local all_tags = {} ---@type table<string, true>
    local help_texts = {}
    for _, map in ipairs(maps) do
        local tags_addtl = list_filter_map_to(map.tags_addtl, function(tag)
            local tag_fmt = tag_from_txt(tag, help_prefix)
            err_if_seen_or_add(all_tags, tag_fmt, "Duplicate tag " .. tag_fmt)
            return tag_fmt
        end)

        -- TODO: Not loving that this is a closure
        local tags_plugs = list_flat_map_to(map.plugs, function(plug)
            local plug_fmt = plug_txt_to_map(help_prefix, plug)
            return list_flat_map_to(map.modes, function(mode)
                local short_modes = mode_map_to_short(mode)
                return list_filter_map_to(short_modes, function(short)
                    local mode_tag = short == "n" and plug_fmt or short .. "_" .. plug_fmt
                    local surrounded = checked_surround(mode_tag, "*")
                    err_if_seen_or_add(all_tags, surrounded, "Duplicate tag " .. surrounded)
                    return surrounded
                end)
            end)
        end)

        local lines = {}
        local tags_addtl_str = table.concat(tags_addtl, " ")
        local wrapped = wrap(tags_addtl_str, 0, 0, MAP_WIDTH, false, true)
        lines[#lines + 1] = wrapped

        for _, tag in ipairs(tags_plugs) do
            lines[#lines + 1] = wrap(tag, 0, 0, MAP_WIDTH, false, true)
        end

        local desc = map.desc_short .. " " .. map.desc
        lines[#lines + 1] = wrap(desc, DESC_INDENT, DESC_INDENT, MAP_WIDTH, true)
        if #map.lhs > 1 then
            lines[#lines + 1] = "By default, mapped to:"
            for _, lh in ipairs(map.lhs) do
                if #lh > 50 then
                    error("lhs " .. lh .. " > 50 bytes")
                end

                local default_wrapped = wrap(lh, TAB_WIDTH * 3, TAB_WIDTH * 3, MAP_WIDTH, false)
                lines[#lines + 1] = default_wrapped
            end
        else
            local lh = map.lhs[1]
            if #lh > 50 then
                error("lhs " .. lh .. " > 50 bytes")
            end

            local default_txt = "By default, mapped to `" .. lh .. "`"
            local default_wrapped = wrap(default_txt, DESC_INDENT, DESC_INDENT, MAP_WIDTH, false)
            lines[#lines + 1] = default_wrapped
        end

        help_texts[#help_texts + 1] = table.concat(lines, "\n")
    end

    return table.concat(help_texts, "\n\n")
end
-- TODO: This also needs to return "all_tags" so that it can be validated against everything
-- else
-- TODO: Rough draft function. Lots of slop in here.

function M.gen_keymap_md(maps)
    -- TODO: validate inputs

    local all_tags = {} ---@type table<string, true>
    local ntl = require("nvim-text-tools.lists")
    local tbl_rows = ntl.filter_map_accum_to(maps, all_tags, function(acc_tags, map)
        local plugs = list_flat_map_to(map.plugs, function(plug)
            return list_flat_map_to(map.modes, function(mode)
                local short_modes = mode_map_to_short(mode)
                return list_filter_map_to(short_modes, function(short)
                    local mode_plug = mode == "n" and plug or short .. "_" .. plug
                    -- TODO: wrong verbiage here
                    err_if_seen_or_add(acc_tags, mode_plug, "Duplicate tag " .. mode_plug)
                    return mode_plug
                end)
            end)
        end)

        ---@diagnostic disable-next-line: assign-type-mismatch
        local defaults = list_filter_map_to(map.lhs, function(lh)
            return checked_surround(lh, "`")
        end)

        local row = {}
        row[1] = table.concat(plugs, ", ")
        row[2] = map.desc_short
        row[3] = table.concat(defaults, ", ")

        return all_tags, row
    end)

    local header_tbl = { "Action(s)", "Desc", "Default(s)" }
    local col_maxes = list_fold(
        tbl_rows,
        { #header_tbl[1], #header_tbl[2], #header_tbl[3] },
        function(acc, row)
            acc[1] = math.max(acc[1], #row[1])
            acc[2] = math.max(acc[2], #row[2])
            acc[3] = math.max(acc[3], #row[3])
            return acc
        end
    )

    list_filter_map_accum(tbl_rows, col_maxes, function(maxes, row)
        local plug_len = #row[1]
        local plug_rpad = maxes[1] - plug_len
        ---@diagnostic disable-next-line: param-type-mismatch
        row[1] = row[1] .. string.rep(" ", plug_rpad)

        local desc_len = #row[2]
        local desc_rpad = maxes[2] - desc_len
        ---@diagnostic disable-next-line: param-type-mismatch
        row[2] = row[2] .. string.rep(" ", desc_rpad)

        local default_len = #row[3]
        local default_rpad = maxes[3] - default_len
        ---@diagnostic disable-next-line: param-type-mismatch
        row[3] = row[3] .. string.rep(" ", default_rpad)

        return maxes, row
    end)

    list_filter_map(tbl_rows, function(row)
        return table.concat(row, " | ")
    end)

    ---@diagnostic disable-next-line: assign-type-mismatch
    local header_delim_tbl = list_filter_map_to(col_maxes, function(col_max)
        return string.rep("-", col_max)
    end)

    -- TODO: It should be one function to create a table and concat it. Intercalate?
    local header_delim = table.concat(header_delim_tbl, " | ")
    list_filter_map_accum(header_tbl, col_maxes, function(maxes, col, idx)
        local len = maxes[idx]
        local len_diff = len - #col
        ---@diagnostic disable-next-line: param-type-mismatch
        return maxes, col .. string.rep(" ", len_diff)
    end)

    local header = table.concat(header_tbl, " | ")

    -- TODO: Really bad because we have to shift the whole table twice
    list_insert_at(tbl_rows, header_delim, 1)
    list_insert_at(tbl_rows, header, 1)

    list_filter_map(tbl_rows, function(row)
        -- TODO: Dumb
        return "| " .. row .. " |"
    end)

    return table.concat(tbl_rows, "\n")
end

---@param maps docgen.keymap.Map[]
---@param help_prefix string
---@return string
function M.gen_default_maps_lua(maps, help_prefix)
    local defaults_tbl = {}
    for _, map in ipairs(maps) do
        for _, plug in ipairs(map.plugs) do
            local plug_fmt = plug_txt_to_map(help_prefix, plug)
            for _, lh in ipairs(map.lhs) do
                for _, mode in ipairs(map.modes) do
                    local parts = {} ---@type string[]

                    parts[#parts + 1] = SET
                    parts[#parts + 1] = '"' .. mode .. '"'
                    parts[#parts + 1] = ", "
                    parts[#parts + 1] = '"' .. lh .. '"'
                    parts[#parts + 1] = ", "
                    parts[#parts + 1] = '"' .. plug_fmt .. '"'

                    parts[#parts + 1] = ", { desc = "
                    local short_mode = mode_map_to_short(mode)[1]
                    local plug_desc = short_mode == "n" and plug_fmt
                        or short_mode .. "_" .. plug_fmt
                    local desc = '"See `:h ' .. plug_desc .. '`"'
                    parts[#parts + 1] = desc
                    parts[#parts + 1] = " })"

                    defaults_tbl[#defaults_tbl + 1] = table.concat(parts)
                end
            end
        end
    end

    return table.concat(defaults_tbl, "\n")
end

---@param maps docgen.keymap.Map[]
---@param help_prefix string
---@return string
function M.gen_plug_maps_lua(maps, help_prefix)
    local plugs_tbl = {}
    for _, map in ipairs(maps) do
        for _, plug in ipairs(map.plugs) do
            local plug_fmt = plug_txt_to_map(help_prefix, plug)
            for _, mode in ipairs(map.modes) do
                local parts = {} ---@type string[]

                parts[#parts + 1] = SET
                parts[#parts + 1] = '"' .. mode .. '"'
                parts[#parts + 1] = ", "
                parts[#parts + 1] = '"' .. plug_fmt .. '"'
                parts[#parts + 1] = ", "
                local callback_txt = map.callback_txt
                if callback_txt and (map.rhs and #map.rhs > 0) then
                    error("Cannot have a callback and an rhs")
                end

                if map.rhs then
                    parts[#parts + 1] = '"' .. map.rhs .. '"'
                else
                    parts[#parts + 1] = '""'
                end

                local opts_parts = {} ---@type string[]
                if callback_txt then
                    local wrapped =
                        wrap(callback_txt, TAB_WIDTH, TAB_WIDTH, LUA_WIDTH, false, false)
                    local callback_assembled = "function()\n" .. wrapped .. "\n    end"
                    local callback_key = "callback = "
                    opts_parts[#opts_parts + 1] = callback_key .. callback_assembled
                end

                local short_mode = mode_map_to_short(mode)[1]
                local plug_desc = short_mode == "n" and plug_fmt or short_mode .. "_" .. plug_fmt
                local desc = '"See `:h ' .. plug_desc .. '`"'
                opts_parts[#opts_parts + 1] = "desc = " .. desc

                local map_opts = map.opts or {}
                if map_opts.noremap == false then
                    opts_parts[#opts_parts + 1] = "noremap = false"
                else
                    opts_parts[#opts_parts + 1] = "noremap = true"
                end

                if map_opts.expr == true then
                    opts_parts[#opts_parts + 1] = "expr = true"
                end

                if map_opts.replace_keycodes == true then
                    opts_parts[#opts_parts + 1] = "replace_keycodes = true"
                end

                if map_opts.unique == true then
                    opts_parts[#opts_parts + 1] = "unique = true"
                end

                if map_opts.silent == true then
                    opts_parts[#opts_parts + 1] = "silent = true"
                end

                local opts_concat = table.concat(opts_parts, ", ")
                local opts_surrounded = "{ " .. opts_concat .. "}"

                parts[#parts + 1] = ", "
                parts[#parts + 1] = opts_surrounded
                parts[#parts + 1] = ")"

                plugs_tbl[#plugs_tbl + 1] = table.concat(parts)
            end
        end
    end

    return table.concat(plugs_tbl, "\n")
end

return M
