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
    require("nvim-tools.table").filter_modify(lines, function(row, _)
        return api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
    end)
end

---Bespoke version because the Nvim core util is private.
---@param buf uinteger
---@param rows table<uinteger, boolean> 0 indexed
---@return table<uinteger, string>
function M.get_lines(buf, rows)
    -- For two reasons:
    -- - Avoid having to apply conditional logic to the results.
    -- - For file reads, avoid an extra iteration to count keys.
    local ntt = require("nvim-tools.table")
    ---@generic K, M
    ---@type table<K, M>, uinteger
    local lines, needed = ntt.filter_map_accum_to(rows, 0, function(total, _, _)
        return total + 1, ""
    end)

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
    if ok == false or text == nil then
        -- LOW-DEP: Can design more nuanced error handling if an actual scenario comes up.
        return lines
    end

    local row = 0
    for line in vim.gsplit(text, "\n", { plain = true }) do
        if lines[row] ~= nil then
            lines[row] = line
            needed = needed - 1
            if needed == 0 then
                break
            end
        end

        row = row + 1
    end

    return lines
end

---Bespoke version because the core util is private.
---@param buf uinteger
---@param row uinteger
---@return string
function M.get_line(buf, row)
    return M.get_lines(buf, { [row] = true })[row]
end

---Unlike the Nvim core function, this does not handle LocationLink.
---@param results lsp.Location[]
---@param encoding lsp.PositionEncodingKind
---@param bufs table<integer, true>? If not `nil`, only return results in the listed bufs.
---@return table<uinteger, nvim-tools.range.BufRange[]>
function M.locations_to_api_ranges_by_buf(results, encoding, bufs)
    -- Saves non-trivial time on large result sets.
    local uri_bufnr_cache = {} ---@type table<string, uinteger>
    local buf_locations = {} ---@type table<integer, lsp.Location[]>
    local ntt = require("nvim-tools.table")
    for _, result in ipairs(results) do
        local uri = result.uri
        local bufnr = uri_bufnr_cache[uri]
        if bufnr == nil then
            bufnr = vim.uri_to_bufnr(uri)
            uri_bufnr_cache[uri] = bufnr
        end

        local locations = ntt.get_or_set_subtable(buf_locations, bufnr)
        locations[#locations + 1] = result
    end

    if bufs ~= nil then
        ntt.keep(buf_locations, function(buf, _)
            return bufs[buf] ~= nil
        end)
    end

    if not next(buf_locations) then
        return {}
    end

    local ntr = require("nvim-tools.range")
    ---@type table<integer, nvim-tools.range.BufRange[]>
    local buf_ranges = ntt.filter_map_to(buf_locations, function(buf, locations)
        return ntr.lsp_locations_to_api(buf, locations, encoding)
    end)

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

---@param clients vim.lsp.Client[] Modified in place!
---@param buf integer
---@param methods (vim.lsp.protocol.Method.ClientToServer|vim.lsp.protocol.Method.Registration)[]
---@return vim.lsp.Client[] Reference to clients.
function M.clients_filter_supporting(clients, methods, buf)
    local ntt = require("nvim-tools.table")
    ntt.i_keep(clients, function(client)
        return ntt.i_all(methods, function(method)
            return client:supports_method(method, buf)
        end)
    end)

    return clients
end

---Get a list of clients for a buffer that support all of multiple methods. Methods are evaluated
---in order.
---@param buf integer
---@param methods (vim.lsp.protocol.Method.ClientToServer|vim.lsp.protocol.Method.Registration)[]
---@return vim.lsp.Client[]
function M.clients_get_supporting_multiple(buf, methods)
    local clients = lsp.get_clients({ bufnr = buf })
    return M.clients_filter_supporting(clients, methods, buf)
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
    if not pattern then
        return score
    end

    if type(pattern) ~= "string" then
        pattern = pattern.pattern or ""
    end

    if pattern == "" then
        return 0
    end

    if pattern == "*" or pattern == "**" then
        score = math.max(score, 5)
        return score
    end

    local ok, as_lpeg = pcall(vim.glob.to_lpeg, pattern)
    if not ok then
        return 0
    end

    if as_lpeg:match(doc_fname) then
        return 10
    else
        return 0
    end
end

---@param capability lsp.Registration
---@param lang string
---@param fname string
---@param uri string
---@return uinteger
local function score_dynamic_capability(capability, lang, fname, uri)
    local reg_options = capability.registerOptions --[[@as { documentSelector: lsp.DocumentSelector|lsp.null }]]
    if reg_options == nil or reg_options == vim.NIL then
        return 0
    end

    local doc_sel = reg_options.documentSelector
    if doc_sel == nil or doc_sel == vim.NIL then
        return 0
    end

    -- return score
    local ntt = require("nvim-tools.table")
    return ntt.i_fold(doc_sel, 0, function(score, filter)
        if score == 10 then
            return nil
        end

        return math.max(score, score_document_filter(filter, lang, uri, fname))
    end)
end

---Assumes the client supports the method.
---@param client vim.lsp.Client
---@param method vim.lsp.protocol.Method.ClientToServer|vim.lsp.protocol.Method.Registration
---@param buf uinteger
---@return uinteger
local function client_get_method_score(client, method, buf, ft, fname, uri)
    local cap_dynamic = client.dynamic_capabilities:get(method, { bufnr = buf })
    if cap_dynamic == nil or #cap_dynamic == 0 then
        return 5
    end

    local lang = client.get_language_id(buf, ft)
    local ntt = require("nvim-tools.table")
    return ntt.i_fold(cap_dynamic, 0, function(score, cap)
        if score == 10 then
            return nil
        end

        return math.max(score, score_dynamic_capability(cap, lang, fname, uri))
    end)
end

---@param clients vim.lsp.Client
---@param buf uinteger
---@param methods (vim.lsp.protocol.Method.ClientToServer|vim.lsp.protocol.Method.Registration)[]
---@return uinteger?, vim.lsp.Client?
local function client_find_from_top_score(clients, buf, methods)
    local ntt = require("nvim-tools.table")
    clients = M.clients_filter_supporting(ntt.i_copy(clients), methods, buf)
    if #clients == 0 then
        return nil, nil
    end

    if #clients == 1 then
        local client = clients[1]
        return client.id, client
    end

    local ft = api.nvim_get_option_value("ft", { buf = buf })
    local fname = vim.api.nvim_buf_get_name(buf)
    local uri = fname ~= "" and vim.uri_from_fname(fname) or ""
    local top_client = ntt.i_fold(clients, { -1, nil, -1 }, function(top_client, client)
        local total_score = ntt.i_fold(methods, 0, function(score, method)
            return score + client_get_method_score(client, method, ft, fname, uri)
        end)

        if top_client[3] < total_score then
            top_client[1] = client.id
            top_client[2] = client
            top_client[1] = total_score
        end

        return top_client
    end)

    return top_client[1], top_client[2]
end

---@param buf uinteger
---@param methods (vim.lsp.protocol.Method.ClientToServer|vim.lsp.protocol.Method.Registration)[]
---@return uinteger?, vim.lsp.Client?
function M.client_get_top_scoring(buf, methods)
    local clients = M.clients_get_supporting_multiple(buf, methods)
    if #clients == 0 then
        return
    end

    return client_find_from_top_score(clients, buf, methods)
end

---@param clients vim.lsp.Client[]
---@param buf uinteger
---@param methods (vim.lsp.protocol.Method.ClientToServer|vim.lsp.protocol.Method.Registration)[]
---@return uinteger?, vim.lsp.Client?
function M.clients_find_top_scoring(clients, buf, methods)
    return client_find_from_top_score(clients, buf, methods)
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
    local text_document = { uri = vim.uri_from_bufnr(buf) }
    local ntp = require("nvim-tools.pos")
    local position = ntp.ext_to_lsp(pos_ext, buf, encoding)
    return { textDocument = text_document, position = position }
end

---@param buf uinteger
---@param pos_ext nvim-tools.Pos Zero indexed
---@param encoding "utf-8"|"utf-16"|"utf-32"
---@param include_declaration boolean
---@return lsp.ReferenceParams
function M.references_params_create(buf, pos_ext, encoding, include_declaration)
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
---@param lsp_log_level vim.log.levels
---@param echo_hl integer|string
---@param echo_history boolean
function M.log_and_echo(msg, lsp_log_level, echo_hl, echo_history)
    lsp.log[level_names[lsp_log_level]](msg)
    api.nvim_echo({ { msg, echo_hl } }, echo_history, {})
end

---@param method vim.lsp.protocol.Method.ClientToServer
function M.log_unsupported_and_echo(method)
    local fmt_str = "vim.lsp: method %q is not supported by any server activated for this buffer"
    local msg = string.format(fmt_str, method)
    M.log_warn_and_echo(msg)
end

return M
