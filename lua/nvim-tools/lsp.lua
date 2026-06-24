local api = vim.api
local fn = vim.fn
local fs = vim.fs
local lsp = vim.lsp

local M = {}

-------------------------------
-- MARK: Position Conversion --
-------------------------------

---@param buf integer
---@param lines table<integer, string> 0 indexed
local function get_lines_from_buf_loaded(buf, lines)
    for row, _ in pairs(lines) do
        lines[row] = api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
    end
end

---Bespoke version because the core util is private.
---@param buf uinteger
---@param rows table<uinteger, boolean> 0 indexed
---@return table<uinteger, string>
function M.get_lines(buf, rows)
    local lines = {} ---@type table<uinteger, string>
    -- Do this to avoid conditional logic when running str indexing functions.
    for row, _ in pairs(rows) do
        lines[row] = ""
    end

    if api.nvim_buf_is_loaded(buf) then
        get_lines_from_buf_loaded(buf, lines)
        return lines
    end

    if not vim.startswith(vim.uri_from_bufnr(buf), "file://") then
        fn.bufload(buf)
        get_lines_from_buf_loaded(buf, lines)
        return lines
    end

    local ntf = require("nvim-tools.fs")
    local bufname_full = api.nvim_buf_get_name(buf)
    local abs_path = fs.normalize(vim.call("fnamemodify", bufname_full, ":p"))
    local ok, text = ntf.read_file(abs_path)

    if not (ok and text) then
        return {}
    end

    local ntt = require("nvim-tools.table")
    local rows_needed = ntt.keys_count(lines)
    local row = 0
    for line in vim.gsplit(text, "\n", { plain = true }) do
        if lines[row] ~= nil then
            lines[row] = line
            rows_needed = rows_needed - 1
            if rows_needed == 0 then
                break
            end
        end

        row = row + 1
    end

    return lines
end
-- MID: Unsure how to better represent rows. Both a uinteger[] and a table<uinteger, string> make
-- the abstraction leaky. The list because the caller has to know it needs to be de-duped, and
-- the table because the caller has to know the string will be overwritten. The current method
-- properly forces uniqueness and hides implementation detail.

---Bespoke version because the core util is private.
---@param buf uinteger
---@param row uinteger
---@return string
function M.get_line(buf, row)
    return M.get_lines(buf, { [row] = true })[row]
end

---This handles both Location and LocationLink objects. If the object is a location link, it
---will pull from the targetSelectionRange.
---@param results lsp.Location[]|lsp.LocationLink[]
---@param encoding lsp.PositionEncodingKind
---@param bufs table<integer, true>? If not `nil`, only return results in the listed bufs.
---@return table<uinteger, nvim-tools.range.BufRange>
function M.ranges_from_locations_by_buf(results, encoding, bufs)
    local ntl = require("nvim-tools.list")
    ---@type table<integer, (lsp.Location[]|lsp.LocationLink[])>
    local buf_locations = ntl.group_by(results, function(result)
        -- locations may be Location or LocationLink
        local uri = result.uri or result.targetUri
        return vim.uri_to_bufnr(uri)
    end)

    if bufs ~= nil then
        for buf, _ in pairs(buf_locations) do
            if bufs[buf] == nil then
                buf_locations[buf] = nil
            end
        end
    end

    local ntr = require("nvim-tools.range")
    local ntt = require("nvim-tools.table")
    ---@type table<integer, nvim-tools.range.BufRange[]>
    local buf_ranges = ntt.filter_map_to(buf_locations, function(buf, locations)
        return ntr.lsp_locations_to_ext(buf, locations, encoding)
    end)

    if encoding ~= "utf-8" then
        for _, ranges in pairs(buf_ranges) do
            ntl.filter(ranges, function(range)
                return ntr.valid_(range)
            end)
        end
    end

    for _, ranges in pairs(buf_ranges) do
        vim.list.unique(ranges, ntr.bit_pack_key)
    end

    for _, ranges in pairs(buf_ranges) do
        table.sort(ranges, ntr.range_sort_predicate_asc)
    end

    return buf_ranges
end

--------------------------
-- MARK: Client Getting --
--------------------------

---Get a list of clients for a buffer that support all of multiple methods. Methods are evaluated
---in order.
---@param bufnr integer
---@param methods (vim.lsp.protocol.Method.ClientToServer|vim.lsp.protocol.Method.Registration)[]
---@return vim.lsp.Client[]
function M.clients_get_supporting_multiple(bufnr, methods)
    local clients = lsp.get_clients({ bufnr = bufnr })
    if #clients == 0 then
        return clients
    end

    local ntl = require("nvim-tools.list")
    ntl.filter(clients, function(client)
        return ntl.all(methods, function(method)
            return client:supports_method(method, bufnr)
        end)
    end)

    return clients
end

---@param filter lsp.DocumentFilter
---@param doc_language string
---@param doc_uri string
---@param doc_fname string
---@return integer
local function score_document_filter(filter, doc_language, doc_uri, doc_fname)
    local score = 0
    local language = filter.language
    if language then
        if language == doc_language then
            score = 10
        elseif language == "*" then
            score = 5
        else
            return 0
        end
    end

    local scheme = filter.scheme
    if scheme then
        if scheme == (string.match(doc_uri, "^[^:]+") or "") then
            score = 10
        elseif scheme == "*" then
            score = math.max(score, 5)
        else
            return 0
        end
    end

    local pattern = filter.pattern
    if pattern then
        if type(pattern) ~= "string" then
            pattern = pattern.pattern or ""
        end

        if pattern == "" then
            return 0
        end

        if pattern == "*" or pattern == "**" then
            score = math.max(score, 5)
        elseif vim.glob.to_lpeg(pattern):match(doc_fname) then
            score = 10
        else
            return 0
        end
    end

    return score
end

---@param capability lsp.Registration
---@param lang string
---@param fname string
---@param uri string
---@return uinteger
local function score_dynamic_capability(capability, lang, fname, uri)
    local reg_options = capability.registerOptions --[[@as { documentSelector: lsp.DocumentSelector|lsp.null }]]
    if (not reg_options) or reg_options == vim.NIL then
        return 0
    end

    local doc_sel = reg_options.documentSelector
    if (not doc_sel) or doc_sel == vim.NIL then
        return 0
    end

    local score = 0
    for _, filter in ipairs(doc_sel) do
        score = math.max(score, score_document_filter(filter, lang, uri, fname))
        if score == 10 then
            return score
        end
    end

    return score
end

---@param clients vim.lsp.Client[]
---@param methods (vim.lsp.protocol.Method.ClientToServer|vim.lsp.protocol.Method.Registration)[]
---@param buf uinteger
---@return -1|uinteger, vim.lsp.Client?
function M.clients_find_best_scoring(clients, methods, buf)
    if #clients == 0 then
        return -1, nil
    end

    local ft = api.nvim_get_option_value("ft", { buf = buf })
    local fname = vim.api.nvim_buf_get_name(buf)
    local uri = fname ~= "" and vim.uri_from_fname(fname) or ""

    local top_id = -1
    local top_score = -1
    local top_client = nil

    for _, c in ipairs(clients) do
        local total_score = 0
        for _, method in ipairs(methods) do
            local cap_dynamic = c.dynamic_capabilities:get(method, { bufnr = buf })
            local method_score = 0
            if cap_dynamic and #cap_dynamic > 0 then
                local lang = c.get_language_id(buf, ft)
                for _, cap in ipairs(cap_dynamic) do
                    local reg_score = score_dynamic_capability(cap, lang, fname, uri)
                    method_score = math.max(method_score, reg_score)
                    if method_score == 10 then
                        break
                    end
                end
            else
                method_score = 5
            end

            total_score = total_score + method_score
        end

        if total_score > top_score then
            top_id = c.id
            top_client = c
            top_score = total_score
        end
    end

    return top_id, top_client
end

---@param buf uinteger
---@param methods (vim.lsp.protocol.Method.ClientToServer|vim.lsp.protocol.Method.Registration)[]
---@return uinteger?, vim.lsp.Client?
function M.client_get_from_doc_sel_score(buf, methods)
    local clients = M.clients_get_supporting_multiple(buf, methods)
    if not clients or #clients == 0 then
        return
    end

    return M.clients_find_best_scoring(clients, methods, buf)
end

----------------------------------
-- MARK: Request Param Creation --
----------------------------------

---Creates a `TextDocumentPositionParams` object for the current buffer and cursor position.
---@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocumentPositionParams
---@param buf uinteger
---@param pos_ext nvim-tools.Pos Zero indexed
---@param encoding "utf-8"|"utf-16"|"utf-32"
---@return lsp.TextDocumentPositionParams
function M.text_doc_pos_params_create(buf, pos_ext, encoding)
    local text_document = vim.lsp.util.make_text_document_params(buf)
    local ntp = require("nvim-tools.pos")
    local position = ntp.ext_to_lsp(pos_ext, buf, encoding)
    return { textDocument = text_document, position = position }
end

---@param buf uinteger
---@param pos_ext nvim-tools.Pos Zero indexed
---@param encoding "utf-8"|"utf-16"|"utf-32"
---@param include_declaration boolean
---@return lsp.ReferenceParams
function M.reference_params_create(buf, pos_ext, encoding, include_declaration)
    local params = M.text_doc_pos_params_create(buf, pos_ext, encoding) --[[@as lsp.ReferenceParams]]
    params.context = { includeDeclaration = include_declaration }
    return params
end

---@param buf uinteger
---@param pos_ext nvim-tools.Pos Zero indexed
---@param encoding "utf-8"|"utf-16"|"utf-32"
---@param new_name string
---@return lsp.RenameParams
function M.rename_params_create(buf, pos_ext, encoding, new_name)
    local params = M.text_doc_pos_params_create(buf, pos_ext, encoding) --[[@as lsp.RenameParams]]
    params.newName = new_name
    return params
end

-------------------
-- MARK: Logging --
-------------------

---@param msg string
function M.log_warn_and_echo(msg)
    api.nvim_echo({ { msg, "WarningMsg" } }, true, {})
    lsp.log.warn(msg)
end
-- TODO: Replace all with log_and_echo

---@param msg string
function M.log_error_and_echo(msg)
    api.nvim_echo({ { msg, "ErrorMsg" } }, true, {})
    lsp.log.error(msg)
end
-- TODO: Replace all with log_and_echo

local level_names = {
    [0] = "trace",
    [1] = "debug",
    [2] = "info",
    [3] = "warn",
    [4] = "error",
    [5] = "off",
}

---@param msg string
---@param log_level vim.log.levels
---@param hl integer|string
---@param history boolean
function M.log_and_echo(msg, log_level, hl, history)
    lsp.log[level_names[log_level]](msg)
    api.nvim_echo({ { msg, hl } }, history, {})
end

---@param method vim.lsp.protocol.Method.ClientToServer
function M.log_unsupported_and_echo(method)
    local fmt_str = "vim.lsp: method %q is not supported by any server activated for this buffer"
    local msg = string.format(fmt_str, method)
    M.log_warn_and_echo(msg)
end

return M
