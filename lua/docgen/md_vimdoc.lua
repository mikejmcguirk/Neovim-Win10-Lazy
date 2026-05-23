#!/usr/bin/env -S nvim -l

if not jit then
    error("Requires Neovim built with LuaJIT to run.")
end

local fs = vim.fs
local ts = vim.treesitter
local uv = vim.uv

local logger = require("docgen.logger")
local log_warning = logger.log_warning

local util = require("docgen.util")
-- local table_copy = util.table_copy
local wrap = util.wrap

local TEXT_WIDTH = 78

local M = {}

---@alias docgen.md.NodeHandler fun(node:TSNode, str:string, ctx:table, handlers:table<string, docgen.md.NodeHandler>): string?

---@class docgen.md.NodeCtx
---@field indent? integer
---@field start_pos? [integer, integer]
---@field end_pos? [integer, integer]
---@field wrap? boolean

---@param str string
---@param lang string
---@param new_opts? vim.treesitter.LanguageTree.new.Opts
---@return TSNode?
local function root_from_str(str, lang, new_opts)
    local parser = vim.treesitter.languagetree.new(str, lang, new_opts)
    return parser:parse(true)[1]:root()
end

-- ---@param node TSNode
-- ---@return TSNode? zeroeth_child
-- local function get_zeroeth_child(node)
--     return node:child_count() > 0 and node:child(0) or nil
-- end

---@param node TSNode
---@param str string
---@param ctx table
---@param handlers table<string, docgen.md.NodeHandler>
---@return string?
local function node_to_str(node, str, ctx, handlers)
    local node_type = node:type()
    local handler = handlers[node_type] or handlers["_default"]
    return handler(node, str, ctx, handlers)

    -- local handled = handler(node, str, ctx, handlers)
    -- if not handled then
    --     return nil
    -- end
    -- -- print(vim.inspect(handled))
    -- local text = tostring(handled)
    -- local start = "<" .. node_type .. ">"
    -- local fin = "</" .. node_type .. ">"
    -- return start .. text .. fin
end

-- ---@param ctx docgen.md.NodeCtx
-- ---@param new_ctx docgen.md.NodeCtx
-- local function ctx_get_updated(ctx, new_ctx)
--     return vim.tbl_extend("force", table_copy(ctx), new_ctx)
-- end

-- ---@type docgen.md.NodeHandler
-- local function get_node_text(node, str)
--     return ts.get_node_text(node, str)
-- end

---@param last_byte integer
---@param this_byte integer
---@param str string
---@param ret string[] Modified in place
local function add_gap_checked(last_byte, this_byte, str, ret)
    if last_byte < this_byte then
        local gap = string.sub(str, last_byte, this_byte - 1)
        if gap ~= nil and string.find(gap, "[^%s]") ~= nil then
            ret[#ret + 1] = gap
        end
    end
end

---@type docgen.md.NodeHandler
local function children_iter(node, str, ctx, handlers)
    local node_type = node:type()
    local _, start_col, start_byte = node:start()
    local sbyte_1 = start_byte + 1

    local indent = 0
    local wrap_this = false
    if node_type == "list_item" then
        indent = start_col * 2 -- Because md is two-space indenting
        wrap_this = true
    end

    local ret = {}
    if indent > 0 and not wrap_this then
        ret[#ret + 1] = string.rep(" ", indent)
    end

    local concat_sep = ""
    if node_type == "document" or node_type == "section" or node_type == "list" then
        concat_sep = "\n"
    end

    local prev_row = nil
    for child, _ in node:iter_children() do
        local row, _, byte = child:start()
        local byte_1 = byte + 1
        add_gap_checked(sbyte_1, byte_1, str, ret)

        local child_type = child:type()
        if child_type == "list" and node_type ~= "section" and concat_sep == "" then
            ret[#ret + 1] = "\n"
        end

        if node_type == "section" and ret[#ret] ~= "" and prev_row and row - prev_row > 1 then
            ret[#ret + 1] = ""
        end

        local node_text = node_to_str(child, str, ctx, handlers)
        if node_text ~= nil and string.find(node_text, "[^%s]") ~= nil then
            ret[#ret + 1] = node_to_str(child, str, ctx, handlers)
        end

        prev_row = row
        local _, _, byte_ = child:end_()
        sbyte_1 = byte_ + 1
    end

    -- if node_type == "document" then
    --     -- print("Ret before: ", vim.inspect(ret))
    -- end

    local _, _, ebyte_ = node:end_()
    local ebyte_1_ = ebyte_ + 1
    add_gap_checked(sbyte_1, ebyte_1_, str, ret)

    local concat = table.concat(ret, concat_sep)
    if wrap_this then
        concat = wrap(concat, indent, indent, TEXT_WIDTH, false)
    end

    return concat
end

---@type docgen.md.NodeHandler
local function node_get_bullet(_, _, _, _)
    return "• "
end

---@param node TSNode
---@return TSNode? zeroeth_child
local function get_zeroeth_child(node)
    return node:child_count() > 0 and node:child(0) or nil
end

---@type docgen.md.NodeHandler
local function node_get_text(node, str, _, _)
    return ts.get_node_text(node, str)
end

---@type table<string, docgen.md.NodeHandler>
local inline_handlers = {
    ["backslash_escape"] = node_get_text,
    ["code_span"] = node_get_text,
    ["emphasis"] = children_iter,
    ["emphasis_delimiter"] = function() end,
    ["image"] = function() end,
    ["inline"] = children_iter,
    ["inline_link"] = function(node, str, _, _)
        for child, _ in node:iter_children() do
            if child:type() == "link_text" then
                return "|" .. ts.get_node_text(child, str) .. "|"
            end
        end
    end,
    -- TODO: This works because you can then convert section headers into tags.
    ["shortcut_link"] = function(node, str, _, _)
        local zeroeth_child = get_zeroeth_child(node)
        if not zeroeth_child then
            return ""
        end

        local node_text = ts.get_node_text(zeroeth_child, str)
        if string.find(node_text, "^<.*>$") then
            return node_text
        elseif string.find(node_text, "^%d+$") then
            return "[" .. node_text .. "]"
        else
            return "|" .. node_text .. "|"
        end
    end,
    -- TODO: I'm not sure if any of this is right.
    ["strong"] = function(node, str, _, _)
        return string.sub(ts.get_node_text(node, str), 3, -3)
    end,
    -- TODO: Has to be a better way to do this.
    ["strong_emphasis"] = children_iter,
    ["text"] = node_get_text,
    ["_default"] = function(node, str, _, _)
        -- TODO: Print warning
        return ts.get_node_text(node, str)
    end,
}

---@type table<string, docgen.md.NodeHandler>
local md_handlers = {

    ["atx_heading"] = function(node, str, _, _)
        -- TODO: Add different header types depending on the # count
        local node_text = ts.get_node_text(node, str)
        node_text = string.gsub(node_text, "\n+$", "")
        return node_text
    end,
    ["block_continuation"] = function() end,
    -- TODO: Treat "block_quote" like a sub-section header. So the first part of it would have
    -- one indent, the others two indents, and the first part would format with the tilde
    ["code_fence_content"] = node_get_text,
    ["document"] = children_iter,
    ["end_tag"] = function() end,
    ["fenced_code_block"] = function(node, str, _, _)
        local ret = {}
        ret[#ret + 1] = ">"
        for child, _ in node:iter_children() do
            if child:type() == "info_string" then
                ret[#ret + 1] = ts.get_node_text(child, str)
                break
            end
        end

        ret[#ret + 1] = "\n"
        for child, _ in node:iter_children() do
            if child:type() == "code_fence_content" then
                ret[#ret + 1] = ts.get_node_text(child, str)
            end
        end

        ret[#ret + 1] = "<"
        local concat = table.concat(ret)
        return concat
    end,
    ["html_block"] = function() end,
    ["html_tag"] = function() end,
    ["inline"] = function(node, str, ctx, _)
        local i_text = ts.get_node_text(node, str)
        if i_text == "" then
            return ""
        end

        i_text = string.gsub(i_text, "\n%s+", "\n")
        i_text = string.gsub(i_text, "\n+", function(match)
            if #match == 1 then
                return " "
            else
                return "\n\n"
            end
        end)

        local i_root = root_from_str(i_text, "markdown_inline")
        if i_root then
            return node_to_str(i_root, i_text, ctx, inline_handlers)
        else
            return i_text
        end
    end,
    ["list"] = children_iter,
    ["list_item"] = children_iter,
    ["list_marker_dot"] = node_get_text,
    ["list_marker_minus"] = node_get_bullet,
    ["list_marker_plus"] = node_get_bullet,
    ["list_marker_star"] = node_get_bullet,
    ["paragraph"] = function(node, str, ctx, handlers)
        local ret = {}
        for child, _ in node:iter_children() do
            ret[#ret + 1] = node_to_str(child, str, ctx, handlers)
        end

        return table.concat(ret, "\n")
    end,
    ["section"] = children_iter,
    ["start_tag"] = function() end,
    ["text"] = node_get_text,
    ["_default"] = function(node, str, ctx, handlers)
        local node_type = node:type()
        log_warning("No md handler for node type " .. node_type)
        local child_count = node:child_count()
        if child_count == 0 then
            return ts.get_node_text(node, str)
        end

        local ret = {}

        local i = 0
        for child, _ in node:iter_children() do
            i = i + 1
            node_to_str(child, str, ctx, handlers)

            if node_type ~= "list" and i ~= child_count then
                local next_child = node:child(i) -- node:child() is zero indexed
                if next_child and next_child:type() ~= "list" then
                    ret[#ret + 1] = "\n"
                end
            end
        end

        return table.concat(ret)
    end,
}

---@param content string
---@return string
function M.md_to_vimdoc(content)
    local root = root_from_str(content .. "\n", "markdown", { injections = { markdown = "" } })
    if not root then
        log_warning("Cannot get root node. Returning content.")
        return content
    end

    local parsed = node_to_str(root, content, {}, md_handlers)
    if not parsed then
        return ""
    end

    -- str_fmt = string.gsub(string.gsub(str_fmt, "\n+$", ""), "^\n", "")
    -- str_fmt = string.gsub(str_fmt, NBSP, " ")
    -- str_fmt = string.gsub(str_fmt, "\n+%s*>([a-z]+)\n", " >%1\n")
    -- str_fmt = string.gsub(str_fmt, "\n+%s*>\n?\n", " >\n")

    parsed = string.gsub(string.gsub(parsed, "\n+$", ""), "^\n+", "")
    return parsed
end

---@param content string
---@return string
function M.luacats_md_to_vimdoc(content)
    return M.md_to_vimdoc(content)
end

-----------------------
-- MARK: Entry Point --
-----------------------

---@param path string[]
---@param output string?
local function validate_params(path, output)
    vim.validate("path", path, "string", true)
    vim.validate("output", output, "string", true)
end
function M.start(path, output)
    validate_params(path, output)

    print("Getting input")
    path = fs.normalize(vim.call("fnamemodify", path, ":p"))
    local fd, o_err, o_err_name = uv.fs_open(path, "r", 292)
    if not fd then
        error(tostring(o_err) .. ": " .. tostring(o_err_name))
    end

    local stat, s_err, s_err_name = uv.fs_fstat(fd)
    if not stat then
        uv.fs_close(fd)
        error(tostring(s_err) .. ": " .. tostring(s_err_name))
    end

    local content, r_err, r_err_name = uv.fs_read(fd, stat.size, 0)
    uv.fs_close(fd)
    if not content then
        error(tostring(r_err) .. ": " .. tostring(r_err_name))
    end

    print("Parsing data")
    local parsed = M.md_to_vimdoc(content)

    print("Writing output")
    path = fs.normalize(vim.call("fnamemodify", output, ":p"))
    local e_stat, e_err, e_err_name = uv.fs_stat(output)
    if (e_stat and e_stat.type ~= "file") or ((not e_stat) and e_err_name ~= "ENOENT") then
        error(tostring(e_err) .. ": " .. tostring(e_err_name))
    end

    if e_stat then
        local permission, a_err, a_err_name = uv.fs_access(output, "W")
        if not permission then
            error(tostring(a_err) .. ": " .. tostring(a_err_name))
        end
    end

    local p_fd, p_err, p_err_name = uv.fs_open(path, "w", 438)
    if not p_fd then
        error(tostring(p_err) .. ": " .. tostring(p_err_name))
    end

    local w_bytes, w_err, w_err_name = uv.fs_write(fd, parsed)
    uv.fs_close(p_fd)
    if not w_bytes then
        error(tostring(w_err) .. ": " .. tostring(w_err_name))
    end

    print("Complete")
end

return M
