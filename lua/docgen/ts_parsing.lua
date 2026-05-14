-----------------------
-- MARK: Boilerplate --
-----------------------

local treesitter = vim.treesitter
local util = require("docgen.util")
local adj_newlines = util.adj_newlines
local do_over_lines = util.do_over_lines
local list_map = util.list_map
local slice_lines = util.slice_lines

local const = require("docgen.const")
local NBSP = const.NBSP
local TEXT_WIDTH = const.TEXT_WIDTH

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

---@param node TSNode
---@param str string
---@param ret string[] -- Edited in place
---@param handlers table<string, fun(node:TSNode, str:string, ret:string[], handlers:table)>
local function node_to_lines(node, str, ret, handlers)
    local node_type = node:type()
    -- ret[#ret + 1] = "<" .. node_type .. ">"

    local handler = assert(handlers[node_type] or handlers["_default"])
    handler(node, str, ret, handlers)
    -- ret[#ret + 1] = "</" .. node_type .. ">"
end
-- LOW: The handler assertion could have a more detailed error message.
-- MAYBE: If we don't want to always exclude punctuation nodes, we could add an "_exclusions" key
-- to handlers. Slow, but portable.

---------------------------
-- MARK: Handler Helpers --
---------------------------

---@param node TSNode
---@param str string
---@param ret string[]
local function add_node_text_and_stop(node, str, ret, _)
    ret[#ret + 1] = treesitter.get_node_text(node, str)
end

---@param line string
---@return string line
local function align_tags(line)
    local tag_pat = "%s*(%*.+%*)%s*$"
    local tags = {}
    for m in line:gmatch(tag_pat) do
        table.insert(tags, m)
    end

    if #tags > 0 then
        line = line:gsub(tag_pat, "")
        local tags_str = " " .. table.concat(tags, " ")
        --- @type integer
        local conceal_offset = select(2, tags_str:gsub("%*", "")) - 2
        local pad = string.rep(" ", TEXT_WIDTH - #line - #tags_str + conceal_offset)
        return line .. pad .. tags_str
    end

    return line
end
-- TODO: Touch this up.

---@param node TSNode
---@return TSNode? zeroeth_child
local function get_zeroeth_child(node)
    return node:child_count() > 0 and node:child(0) or nil
end

---@param node TSNode
---@param str string
---@param ret string[] Edited in place
---@param handlers table<string, fun(node:TSNode, str:string, ret:string[], handlers:table)>
local function iter_all_children(node, str, ret, handlers)
    for child, _ in node:iter_children() do
        node_to_lines(child, str, ret, handlers)
    end
end

--------------------
-- MARK: Handlers --
--------------------

---@type table<string, fun(node:TSNode, str:string, ret:string[], handlers:table)>
local md_inline_handlers = {
    ["backslash_escape"] = add_node_text_and_stop,
    ["code_span"] = function(node, str, ret, _)
        local node_text = treesitter.get_node_text(node, str)

        ret[#ret + 1] = "`"
        ret[#ret + 1] = string.gsub(string.sub(node_text, 2, -2), " ", NBSP)
        ret[#ret + 1] = "`"
    end,
    ["emphasis"] = function(node, str, ret, _)
        ret[#ret + 1] = string.sub(treesitter.get_node_text(node, str), 2, -2)
    end,
    -- Use adj_lines on gap areas here because we might not wrap later.
    ["inline"] = function(node, str, ret, handlers)
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

                node_to_lines(child, str, ret, handlers)
                row, col = child:end_()
            end
        end

        local trailing = slice_lines(lines, row, col)
        if trailing and trailing ~= "" then
            ret[#ret + 1] = adj_newlines(trailing)
        end
    end,
    ["inline_link"] = function(node, str, ret, _)
        local zeroeth_child = get_zeroeth_child(node)
        if not zeroeth_child then
            return
        end

        ret[#ret + 1] = "*"
        ret[#ret + 1] = treesitter.get_node_text(zeroeth_child, str)
        ret[#ret + 1] = "*"
    end,
    ["shortcut_link"] = function(node, str, ret, _)
        local zeroeth_child = get_zeroeth_child(node)
        if not zeroeth_child then
            return
        end

        local node_text = treesitter.get_node_text(zeroeth_child, str)
        if string.find(node_text, "^<.*>$") then
            ret[#ret + 1] = node_text
            return
        end

        local all_nums = string.find(node_text, "^%d+$")
        ret[#ret + 1] = all_nums and "[" or "|"
        ret[#ret + 1] = node_text
        ret[#ret + 1] = all_nums and "]" or "|"
    end,
    ["strong"] = function(node, str, ret, _)
        ret[#ret + 1] = string.sub(treesitter.get_node_text(node, str), 3, -3)
    end,
    ["text"] = add_node_text_and_stop,
    ["_default"] = function(node, str, ret, _)
        ret[#ret + 1] = treesitter.get_node_text(node, str)
    end,
}

---@type table<string, fun(node:TSNode, str:string, ret:string[], handlers:table)>
local md_handlers = {
    ["block_continuation"] = function() end,
    ["code_fence_content"] = function(node, str, ret, _)
        local text = treesitter.get_node_text(node, str)
        local lines = vim.split(string.gsub(text, "\n%s*$", ""), "\n")

        for _, line in ipairs(lines) do
            if #line > 0 then
                ret[#ret + 1] = line
            end

            ret[#ret + 1] = "\n"
        end
    end,
    -- MAYBE: Re-introduce the manual indent parsing if needed.
    ["document"] = iter_all_children,
    ["fenced_code_block"] = function(node, str, ret, handlers)
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
                node_to_lines(child, str, ret, handlers)
            end
        end

        ret[#ret + 1] = "<\n"
    end,
    ["fenced_code_block_delimiter"] = iter_all_children,
    ["html_block"] = function(node, str, ret, _)
        local text = treesitter.get_node_text(node, str)
        text = string.gsub(text, "^<pre>help", "")
        text = string.gsub(text, "</pre>%s*$", "")
        ret[#ret + 1] = text
    end,
    ["html_tag"] = function(node, str, _, _)
        error("html_tag: " .. treesitter.get_node_text(node, str))
    end,
    ["inline"] = function(node, str, ret, _)
        local i_text = treesitter.get_node_text(node, str)
        if i_text == "" then
            return
        end

        local i_root = root_from_str(i_text, "markdown_inline")
        if i_root then
            node_to_lines(i_root, i_text, ret, md_inline_handlers)
        else
            i_text = adj_newlines(i_text)
            ret[#ret + 1] = i_text
        end
    end,
    ["list"] = iter_all_children,
    ["list_item"] = function(node, str, ret, handlers)
        local zeroeth_child = get_zeroeth_child(node)
        if not zeroeth_child then
            return
        end

        -- Per MariaSolOs: Required since TS vimdoc parser does not support numbered list-items
        -- https://github.com/neovim/tree-sitter-vimdoc/issues/144
        local child_text = treesitter.get_node_text(zeroeth_child, str)
        if string.match(child_text, "[2-9]%.") ~= nil then
            ret[#ret + 1] = "\n"
        end

        local i = 0
        for child, _ in node:iter_children() do
            i = i + 1
            -- TODO: How should this work without the indent value coming in? The idea is that,
            -- for later lines in a bulleted list, you want them indented over. You can't just
            -- wrap because of code blocks.
            node_to_lines(child, str, ret, handlers)
        end
    end,
    ["list_marker_dot"] = add_node_text_and_stop,

    ["list_marker_minus"] = function(_, _, ret, _)
        ret[#ret + 1] = "• "
    end,

    ["list_marker_star"] = function(_, _, ret, _)
        ret[#ret + 1] = "• "
    end,
    ["paragraph"] = function(node, str, ret, handlers)
        if node:child_count() == 0 then
            return
        end

        local para_parts = {}
        for child, _ in node:iter_children() do
            node_to_lines(child, str, para_parts, handlers)
        end

        ret[#ret + 1] = table.concat(para_parts)
        ret[#ret + 1] = "\n"
    end,
    ["section"] = iter_all_children,
    ["text"] = add_node_text_and_stop,
    ["_default"] = function(node, str, ret, handlers)
        local child_count = node:child_count()
        if child_count == 0 then
            ---@diagnostic disable-next-line: empty-block
            if treesitter.get_node_text(node, str) then
                -- TODO: Add --emit-warnings for these
            end
        else
            local i = 0
            local node_type = node:type()
            for child, _ in node:iter_children() do
                i = i + 1
                node_to_lines(child, str, ret, handlers)

                if node_type ~= "list" and i ~= child_count then
                    local next_child = node:child(i) -- node:child() is zero indexed
                    if next_child and next_child:type() ~= "list" then
                        ret[#ret + 1] = "\n"
                    end
                end
            end
        end
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
    local ret = {}
    node_to_lines(root, str, ret, md_handlers)
    local lines = do_over_lines(ret, function(s)
        return string.gsub(string.gsub(s, "\n+$", ""), NBSP, " ")
    end)

    list_map(lines, align_tags)
    local vimdoc = table.concat(lines, "\n")
    vimdoc = string.gsub(vimdoc, "\n+%s*>([a-z]+)\n", " >%1\n")
    vimdoc = string.gsub(vimdoc, "\n+%s*>\n?\n", " >\n")

    return vimdoc
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
