local api = vim.api
local lsp = vim.lsp

local M = {}

---Aggregated location results by bufnr.
---@alias nvim-tools.lsp.locations.Parsed table<integer, [integer, integer, integer, integer][]>

---@param results lsp.Location[]|lsp.LocationLink[]
---@param encoding 'utf-8'|'utf-16'|'utf-32'
---@return nvim-tools.lsp.locations.Parsed
function M.buf_ranges_from_locations(results, encoding)
    local ntl = require("nvim-tools.list")
    ---@type table<integer, (lsp.Location[]|lsp.LocationLink[])>
    local buf_locations = ntl.group_by(results, function(result)
        -- locations may be Location or LocationLink
        local uri = result.uri or result.targetUri
        return vim.uri_to_bufnr(uri)
    end)

    local ntt = require("nvim-tools.table")
    local buf_ranges = ntt.filter_map_to(buf_locations, function(_, locations)
        return ntl.filter_map_to(locations, function(location)
            -- locations may be Location or LocationLink
            local range = location.range or location.targetSelectionRange
            local range_start = range.start
            local range_end = range["end"]
            return {
                range_start.line,
                range_start.character,
                range_end.line,
                range_end.character,
            }
        end)
    end)

    local ntr = require("nvim-tools.range")
    if encoding ~= "utf-8" then
        for buf, ranges in pairs(buf_ranges) do
            ntr.lsp_parsed_locations_convert(buf, ranges, encoding)
        end
    end

    for _, ranges in pairs(buf_ranges) do
        ntl.filter(ranges, function(range)
            return ntr.valid_(range)
        end)
    end

    for _, ranges in pairs(buf_ranges) do
        vim.list.unique(ranges, function(range)
            return bit.lshift(range[1], 0)
                + bit.lshift(range[2], 14)
                + bit.lshift(range[3], 24)
                + bit.lshift(range[4], 38)
        end)
    end

    for _, ranges in pairs(buf_ranges) do
        table.sort(ranges, ntr.range_sort_predicate)
    end

    return buf_ranges
end
-- TODO: Does this fully handle LocationLink? references can only return location, so maybe
-- we want to have like, a location link only converter, a location only converter, and one
-- that handles both.
-- TODO: Verify VSCode behavior.
-- MID: Helix, AFAICT, does no post-processing on reference results, whereas VSCode sorts and
-- de-dupes them. Unlike how Helix handles documentHighlight, there is no overlap handling. This
-- discrepancy feels notable to me and is worth following up on. Is Helix wrong for not doing
-- enough with the results? Or does VSCode play it too safe?

---@param client vim.lsp.Client[]
local function client_get_score(client)
    return 10
end
-- TODO: Fill in the actual VSCode logic.

---@param clients vim.lsp.Client[]
---@return vim.lsp.Client
function M.clients_get_highest_scoring(clients)
    if #clients == 1 then
        return clients[1]
    end

    -- vim.lsp.get_clients takes results from a hash table, so order is not guaranteed.
    table.sort(clients, function(a, b)
        return a.id < b.id
    end)

    local ntl = require("nvim-tools.list")
    return ntl.fold2(clients, function(top_client, top_score, client)
        local new_score = client_get_score(client)
        if new_score > top_score then
            return client, new_score
        else
            return top_client, top_score
        end
    end, nil, client_get_score(clients[1]))
end

---Get a list of clients for a buffer that support all of multiple methods. Methods are evaluated
---in order.
---@param bufnr integer
---@param methods vim.lsp.protocol.Method.ClientToServer[]
---@return vim.lsp.Client[]
function M.clients_get_supporting_multiple(bufnr, methods)
    local clients = lsp.get_clients({ method = methods[1], bufnr = bufnr })
    if #clients == 0 then
        return clients
    end

    local methods_len = #methods
    local ntl = require("nvim-tools.list")
    ntl.filter(clients, function(client)
        for i = 2, methods_len do
            if not client:supports_method(methods[i]) then
                return false
            end
        end

        return true
    end)

    return clients
end

---@param msg string
function M.log_warn_and_echo(msg)
    api.nvim_echo({ { msg, "WarningMsg" } }, true, {})
    lsp.log.warn(msg)
end

---@param msg string
function M.log_error_and_echo(msg)
    api.nvim_echo({ { msg, "ErrorMsg" } }, true, {})
    lsp.log.error(msg)
end

---@param method vim.lsp.protocol.Method.ClientToServer
function M.log_unsupported_and_echo(method)
    local fmt_str = "vim.lsp: method %q is not supported by any server activated for this buffer"
    local msg = string.format(fmt_str, method)
    M.log_warn_and_echo(msg)
end

return M
