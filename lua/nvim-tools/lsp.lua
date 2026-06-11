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

    for _, locations in pairs(buf_locations) do
        ntl.filter_map(locations, function(location)
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
    end

    buf_locations = buf_locations --[[@as nvim-tools.lsp.locations.Parsed]]
    local ntr = require("nvim-tools.range")
    if encoding ~= "utf-8" then
        for buf, ranges in pairs(buf_locations) do
            ntr.lsp_parsed_locations_convert(buf, ranges, encoding)
        end
    end

    for _, ranges in pairs(buf_locations) do
        ntl.filter(ranges, function(range)
            return ntr.valid_(range)
        end)
    end

    for _, ranges in pairs(buf_locations) do
        vim.list.unique(ranges, function(range)
            return bit.lshift(range[1], 0)
                + bit.lshift(range[2], 14)
                + bit.lshift(range[3], 24)
                + bit.lshift(range[4], 38)
        end)
    end

    for _, ranges in pairs(buf_locations) do
        table.sort(ranges, ntr.range_sort_predicate)
    end

    return buf_locations
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

    local best_score = -1
    local best_client_idx = 0
    for i, client in ipairs(clients) do
        local score = client_get_score(client)
        if score > best_score then
            best_client_idx = i
            best_score = score
        end
    end
    -- TODO: The fact I don't have a list function that can handle this is bonkers.
    -- for folding/scanning:
    -- - left to right or right to left? (all functions should have rev flag)
    -- - Is the initial acc the first list value or a custom value?
    --   - I had wanted to use this as the differentiator between fold and reduce but that feels
    --   like a mistake. I think you can/should take it as a given that if init is nil you get
    --   the first value of the table or you can specify init in both reduce and fold
    -- - Do you store acc separately from the return value?
    --   - This might be a good differentiator between reduce and fold
    --  -- - Taking all the above together, reduce only gives you the acc value, initializable or
    --  not, and short circuits on nil, and provides no finishing function. So you can use it
    --  for simple things like sum of all values or whatever. And then fold stores acc/val
    --  separately, has more complex short circuit logic, and maybe can take a finishing
    --  function (so that you can store count and total to do average)
    --
    --  And then there's:
    --  - scan
    --  - transduce
    --  - filter_map_accum
    --  - successors
    --  - unfold
    --
    --  All of which serve overlapping functions.
    --  successors/unfold are probably fine but need another look. Because successors is
    --  just like, use the last value of the list to make the next. And then unfold holds a
    --  separate accumulator, which you also get. That's similarish to what I want to do with
    --  reduce/fold.
    --
    --  scan is supposed to be for simple cumulative whatever functions. Initialize an acc and
    --  then run it over a table.
    --  FIlter_map accum is also fine because it's in place.
    --  Transduce is still the weird one.

    return clients[best_client_idx]
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

return M
