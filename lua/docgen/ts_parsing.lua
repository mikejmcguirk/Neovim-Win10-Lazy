-----------------------
-- MARK: Boilerplate --
-----------------------

local treesitter = vim.treesitter
local util = require("docgen.util")
local adj_newlines = util.adj_newlines
local slice_lines = util.slice_lines

local const = require("docgen.const")
local INDENT = const.INDENT
local NBSP = const.NBSP

-------------------------------------
-- MARK: Tree Extraction/Traversal --
-------------------------------------

---@param str string
---@param lang string
---@param new_opts? vim.treesitter.LanguageTree.new.Opts
---@return TSNode?
local function root_from_str(str, lang, new_opts)
    local parser = vim.treesitter.languagetree.new(str, lang, new_opts)
    return parser:parse(true)[1]:root()
end

---@alias docgen.NodeHandler fun(node:TSNode, str:string, indent:integer, handlers:table): string?

---@param node TSNode
---@param str string
---@param indent integer
---@param handlers table<string, docgen.NodeHandler>
---@return string?
local function node_to_str(node, str, indent, handlers)
    local node_type = node:type()

    local handler = handlers[node_type] or handlers["_default"]
    return handler(node, str, indent, handlers)
end
-- LOW: The handler assertion could have a more detailed error message.
-- MAYBE: If we don't want to always exclude punctuation nodes, we could add an "_exclusions" key
-- to handlers. Slow, but portable.

---------------------------
-- MARK: Handler Helpers --
---------------------------

---@return string
local function handler_node_bullet_get(_, _, _, _)
    return "• "
end

---@param node TSNode
---@param str string
---@return string
local function handler_node_text_get(node, str, _, _)
    return treesitter.get_node_text(node, str)
end

---@param node TSNode
---@return TSNode? zeroeth_child
local function get_zeroeth_child(node)
    return node:child_count() > 0 and node:child(0) or nil
end

---@param node TSNode
---@param str string
---@param indent integer
---@param handlers table<string, docgen.NodeHandler>
---@return string
local function iter_all_children(node, str, indent, handlers)
    local ret = {}
    for child, _ in node:iter_children() do
        ret[#ret + 1] = node_to_str(child, str, indent, handlers)
    end

    return table.concat(ret)
end

--------------------
-- MARK: Handlers --
--------------------

---@type table<string, docgen.NodeHandler>
local md_inline_handlers = {
    ["backslash_escape"] = handler_node_text_get,
    ["code_span"] = handler_node_text_get,
    ["emphasis"] = function(node, str, _, _)
        return string.sub(treesitter.get_node_text(node, str), 2, -2)
    end,
    -- Use adj_lines on gap areas here because we might not wrap later.
    ["inline"] = function(node, str, indent, handlers)
        local ret = {}

        local lines = vim.split(str, "\n")
        local row, col = 0, 0
        for child, _ in node:iter_children() do
            local child_type = child:type()
            if not child_type:match("^%p$") then
                local srow, scol = child:start()
                if (srow == row and scol > col) or srow > row then
                    local gap = slice_lines(lines, row, col, srow, scol)
                    if gap and gap ~= "" then
                        ret[#ret + 1] = adj_newlines(gap)
                    end
                end

                ret[#ret + 1] = node_to_str(child, str, indent, handlers)
                row, col = child:end_()
            end
        end

        local trailing = slice_lines(lines, row, col)
        if trailing and trailing ~= "" then
            ret[#ret + 1] = adj_newlines(trailing)
        end

        return table.concat(ret)
    end,
    ["inline_link"] = function(node, str, _, _)
        local zeroeth_child = get_zeroeth_child(node)
        if not zeroeth_child then
            return ""
        end

        return "*" .. treesitter.get_node_text(zeroeth_child, str) .. "*"
    end,
    ["shortcut_link"] = function(node, str, _, _)
        local zeroeth_child = get_zeroeth_child(node)
        if not zeroeth_child then
            return ""
        end

        local node_text = treesitter.get_node_text(zeroeth_child, str)
        if string.find(node_text, "^<.*>$") then
            return node_text
        elseif string.find(node_text, "^%d+$") then
            return "[" .. node_text .. "]"
        else
            return "|" .. node_text .. "|"
        end
    end,
    ["strong"] = function(node, str, _, _)
        return string.sub(treesitter.get_node_text(node, str), 3, -3)
    end,
    ["text"] = handler_node_text_get,
    ["_default"] = function(node, str, _, _)
        return treesitter.get_node_text(node, str)
    end,
}

---@type table<string, docgen.NodeHandler>
local md_handlers = {
    -- Return nothing because these are nodes of whitespace-only characters
    ["block_continuation"] = function(_, _, _, _) end,
    ["code_fence_content"] = function(node, str, _, _)
        local ret = {}
        local text = treesitter.get_node_text(node, str)
        local lines = vim.split(string.gsub(text, "\n%s*$", ""), "\n")

        for _, line in ipairs(lines) do
            if #line > 0 then
                ret[#ret + 1] = line
            end

            ret[#ret + 1] = "\n"
        end

        -- TODO: I think fix_newlines would work better here, but I need to verify what
        -- this node is.
        return table.concat(ret)
    end,
    -- MAYBE: Re-introduce the manual indent parsing if needed.
    ["document"] = function(node, str, indent, handlers)
        local ret = {}
        for child, _ in node:iter_children() do
            ret[#ret + 1] = node_to_str(child, str, indent, handlers)
        end

        return table.concat(ret, "\n")
    end,
    ["fenced_code_block"] = function(node, str, indent, handlers)
        local ret = {}
        ret[#ret + 1] = ">"
        for child, _ in node:iter_children() do
            if child:type() == "info_string" then
                ret[#ret + 1] = treesitter.get_node_text(child, str)
                break
            end
        end

        ret[#ret + 1] = "\n"
        for child, _ in node:iter_children() do
            if child:type() ~= "info_string" then
                node_to_str(child, str, indent, handlers)
            end
        end

        ret[#ret + 1] = "<\n"
        return table.concat(ret)
    end,
    ["fenced_code_block_delimiter"] = iter_all_children,
    ["html_block"] = function(node, str, _, _)
        local text = treesitter.get_node_text(node, str)
        text = string.gsub(text, "^<pre>help", "")
        text = string.gsub(text, "</pre>%s*$", "")
        return text
    end,
    ["html_tag"] = function(node, str, _, _)
        error("html_tag: " .. treesitter.get_node_text(node, str))
    end,
    ["inline"] = function(node, str, indent, _)
        local i_text = treesitter.get_node_text(node, str)
        if i_text == "" then
            return ""
        end

        local i_root = root_from_str(i_text, "markdown_inline")
        if i_root then
            return node_to_str(i_root, i_text, indent, md_inline_handlers)
        else
            return adj_newlines(i_text)
        end
    end,
    ["list"] = function(node, str, indent, handlers)
        local ret = {}
        local parent = node:parent()
        -- For lists that start within paragraphs.
        if parent and parent:type() ~= "section" then
            ret[#ret + 1] = ""
        end

        local indent_str = string.rep(" ", indent)
        local new_indent = indent + INDENT
        for child, _ in node:iter_children() do
            ret[#ret + 1] = indent_str .. node_to_str(child, str, new_indent, handlers)
        end

        return table.concat(ret, "\n")
    end,
    -- DOC: Lists always try to snap to directly below the previous line.
    -- DOC: You need an empty line after the list to make the next thing appear as not the list.
    -- The markdown parser sees the next line as a continuation of the list item.
    ["list_item"] = function(node, str, indent, handlers)
        local zeroeth_child = get_zeroeth_child(node)
        if not zeroeth_child then
            return ""
        end

        local ret = {}

        -- Required since TS vimdoc parser does not support numbered list-items
        -- https://github.com/neovim/tree-sitter-vimdoc/issues/144
        local child_text = treesitter.get_node_text(zeroeth_child, str)
        if string.match(child_text, "[2-9]%.") ~= nil then
            ret[#ret + 1] = "\n"
        end

        for child, _ in node:iter_children() do
            ret[#ret + 1] = node_to_str(child, str, indent, handlers)
        end

        return table.concat(ret)
    end,
    ["list_marker_dot"] = handler_node_text_get,
    ["list_marker_minus"] = handler_node_bullet_get,
    ["list_marker_star"] = handler_node_bullet_get,
    ["paragraph"] = function(node, str, indent, handlers)
        local ret = {}
        for child, _ in node:iter_children() do
            ret[#ret + 1] = node_to_str(child, str, indent, handlers)
        end

        return table.concat(ret)
    end,
    ["section"] = function(node, str, indent, handlers)
        local ret = {}
        local prev_type
        for child, _ in node:iter_children() do
            local cur_type = child:type()
            if (prev_type ~= nil) and cur_type == "paragraph" then
                ret[#ret + 1] = "" -- Force an additional newline
            end

            prev_type = cur_type
            ret[#ret + 1] = node_to_str(child, str, indent, handlers)
        end

        return table.concat(ret, "\n")
    end,
    -- DOC: Lines with one "\n" between them are mixed together into the same paragraph.
    -- If you use newlines to break into multiple paragraphs, the paragraphs will be given a
    -- newline separation. Paragraphs after lists will always be given a newline.
    ["text"] = handler_node_text_get,
    ["_default"] = function(node, str, indent, handlers)
        local child_count = node:child_count()
        if child_count == 0 then
            ---@diagnostic disable-next-line: empty-block
            if treesitter.get_node_text(node, str) then
                -- TODO: Add --emit-warnings for these
                return ""
            end
        end

        local ret = {}

        local i = 0
        local node_type = node:type()
        for child, _ in node:iter_children() do
            i = i + 1
            node_to_str(child, str, indent, handlers)

            if node_type ~= "list" and i ~= child_count then
                local next_child = node:child(i) -- node:child() is zero indexed
                if next_child and next_child:type() ~= "list" then
                    ret[#ret + 1] = "\n"
                end
            end
        end

        return table.concat(ret)
    end,
    -- LOW: Unfortunate to get node_type again here. Bad though to send it to every handler for
    -- one case.
}

local M = {}

-------------------
-- MARK: Parsing --
-------------------

---@param root TSNode
---@param str string
---@return string
function M.md_tree_to_vimdoc(root, str)
    local str_fmt = node_to_str(root, str, 0, md_handlers)
    if not str_fmt then
        return ""
    end

    str_fmt = string.gsub(string.gsub(str_fmt, "\n+$", ""), "^\n", "")
    str_fmt = string.gsub(str_fmt, NBSP, " ")
    str_fmt = string.gsub(str_fmt, "\n+%s*>([a-z]+)\n", " >%1\n")
    str_fmt = string.gsub(str_fmt, "\n+%s*>\n?\n", " >\n")

    return str_fmt
end

---@param str string
---@return string
function M.luacats_md_to_vimdoc(str)
    -- Add an extra newline so the parser can properly capture ending ```
    local root = root_from_str(str .. "\n", "markdown", { injections = { markdown = "" } })
    if not root then
        return ""
    end

    return M.md_tree_to_vimdoc(root, str)
end
-- TODO: Returning "" on a bad root is fine for the moment, but since this makes it impossible to
-- parse a lot of different types of text, might be better as an error.
-- LOW: Pre-allocate lines. Problem: I'm not sure how to get a reasonable pre-allocation without
-- traversing the tree, which is algorithmically complex. Maybe cap at a certain depth? Maybe at
-- like 16 or 32 you say you have enough to avoid the thrashing at low table lengths.

return M
