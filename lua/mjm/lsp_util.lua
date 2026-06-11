local api = vim.api
local lsp = vim.lsp
local util = vim.lsp.util

local M_TD_REFS = "textDocument/references"

local M = {}

---@param method vim.lsp.protocol.Method.ClientToServer
function M.unsupported_echo_and_log(method)
    local fmt_str = "vim.lsp: method %q is not supported by any server activated for this buffer"
    local msg = string.format(fmt_str, method)
    lsp.log.warn(msg)
    return msg
end

-- first see if any of the clients support prepare rename
-- for clients that support prepare rename, verify they support rename and references
-- if they don't, then just look for clients that support rename and references
-- if you somehow don't have that, at least get one that supports rename

---@param client vim.lsp.Client
---@param buf integer
---@param row integer 0-indexed
---@param col integer 0-indexed, inclusive
---@param include_declaration? boolean
function M.client_get_references(client, buf, row, col, include_declaration)
    if include_declaration == nil then
        include_declaration = true
    end

    local encoding = client.offset_encoding
    local cparams = {
        context = { includeDeclaration = include_declaration },
        position = vim.pos.extmark(buf, row, col):to_lsp(encoding),
        textDocument = util.make_text_document_params(buf),
    }

    -- TODO: Take the ctx validator from documentHighlight and make an nvim-tools version of
    -- it.
    local req_success, req_id = client:request(M_TD_REFS, cparams, function(err, results, ctx)
        -- TODO: Unsure what to do with ctx checking since this is a sketch.
        if err or not results then
            -- TODO: Unsure what to do here since this is kinda just a sketch.
            return
        end

        local nts = require("nvim-tools.lsp")
        local ranges = nts.buf_ranges_from_locations(results, encoding)
    end)
end
-- TODO: Does this need to be an M function?

return M
