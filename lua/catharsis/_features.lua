local api = vim.api
local lsp = vim.lsp

---@class catharsis.Feature
---@field disabled_bufs table<uinteger, true>
---@field disabled_client_ids table<uinteger, true>
---@field spec catharsis.feature.Spec

---@param feature catharsis.Feature
---@param buf uinteger
---@param client_id uinteger
local function feature_disabled_both(feature, buf, client_id)
    return feature.disabled_bufs[buf] and feature.disabled_client_ids[client_id]
end

---@class catharsis.feature.Spec
---@field method vim.lsp.protocol.Method.ClientToServer
---Start work for this buffer.
---@field on_buf_add fun(buf:uinteger)
---Stop work for this buffer.
---@field on_buf_rm fun(buf:uinteger)
---Client detached from a buffer.
---@field on_client_detach fun(buf:uinteger, client_id:uinteger, client:vim.lsp.Client)
---Allow work for this client.
---@field on_client_add fun(client_id:uinteger)
---Deny work for this client.
---@field on_client_rm fun(client_id:uinteger)

---@alias catharsis.features.Names
---|"document_highlight"

---@type [catharsis.features.Names, string][]
local names_to_load = {
    { "document_highlight", "catharsis._document_highlight" },
}

local features = {} ---@type catharsis.Feature[]
local features_enabled = {} ---@type table<uinteger, true>
local features_disabled = {} ---@type table<uinteger, true>
local features_byname = {} ---@type table<string, uinteger>

for _, name in ipairs(names_to_load) do
    local feature = {
        disabled_bufs = {},
        disabled_client_ids = {},
        spec = require(name[2]),
    }

    features[#features + 1] = feature
    features_enabled[#features] = true
    features_byname[name[1]] = #features
end

local group = api.nvim_create_augroup("catharsis.features", {})
api.nvim_create_autocmd("LspAttach", {
    group = group,
    callback = function(ev)
        local client_id = ev.data.client_id
        local client = lsp.get_client_by_id(client_id)
        if client == nil then
            return
        end

        local buf = ev.buf
        for handle, _ in pairs(features_enabled) do
            local feature = features[handle]
            if
                client:supports_method(feature.spec.method)
                and not feature.disabled_bufs[buf]
                and not feature.disabled_client_ids[client_id]
            then
                feature.spec.on_buf_add(buf)
            end
        end
    end,
})

api.nvim_create_autocmd("LspDetach", {
    group = group,
    -- Schedule wrap so that the detached client's active buffers are updated.
    ---@param ev vim.api.keyset.create_autocmd.callback_args
    callback = vim.schedule_wrap(function(ev)
        local buf = ev.buf
        local client_id = ev.data.client_id ---@type uinteger
        local client = lsp.get_client_by_id(client_id)
        if client then
            for handle, _ in pairs(features_enabled) do
                local feature = features[handle]
                if
                    client:supports_method(feature.spec.method, buf)
                    and not feature_disabled_both(feature, buf, client_id)
                then
                    feature.spec.on_client_detach(buf, client_id, client)
                end
            end
        end

        for handle, _ in pairs(features_enabled) do
            local feature = features[handle]
            if feature.disabled_bufs[buf] == nil then
                local method = feature.spec.method
                if #lsp.get_clients({ bufnr = buf, method = method }) == 0 then
                    feature.spec.on_buf_rm(buf)
                end
            end
        end
    end),
})

local M = {}

---@param handle uinteger
---@param outof table<uinteger, true>
---@param into table<uinteger, true>
---@return boolean
local function status_swap(handle, outof, into)
    local needs_out = outof[handle]
    if not needs_out then
        return false
    end

    outof[handle] = nil
    into[handle] = true
    return true
end

---@param handle uinteger
---@param enabled boolean
local function feature_enablement_change(handle, enabled)
    local swapped = enabled and status_swap(handle, features_disabled, features_enabled)
        or status_swap(handle, features_enabled, features_disabled)
    if not swapped then
        return false
    end

    local feature = features[handle]
    local clients = lsp.get_clients({ method = feature.spec.method })
    local feature_disabled_bufs = feature.disabled_bufs
    local on_fn = enabled and feature.spec.on_buf_add or feature.spec.on_buf_rm
    for _, client in ipairs(clients) do
        local bufs = client.attached_buffers
        for buf, _ in pairs(bufs) do
            if not feature_disabled_bufs[buf] then
                on_fn(buf)
            end
        end
    end

    return true
end

---@param feature_name catharsis.features.Names
---@return boolean Did status change?
function M.enable(feature_name)
    local handle = features_byname[feature_name]
    if handle == nil then
        api.nvim_echo({ { "Feature does not exist", "WarningMsg" } }, true, {})
        return false
    end

    return feature_enablement_change(handle, true)
end

---@param feature_name catharsis.features.Names
---@return boolean Did status change?
function M.disable(feature_name)
    local handle = features_byname[feature_name]
    if handle == nil then
        api.nvim_echo({ { "Feature does not exist", "WarningMsg" } }, true, {})
        return false
    end

    return feature_enablement_change(handle, false)
end

---@param feature_name catharsis.features.Names
---@return boolean Did toggle.
function M.toggle(feature_name)
    local handle = features_byname[feature_name]
    if handle == nil then
        api.nvim_echo({ { "Feature does not exist", "WarningMsg" } }, true, {})
        return false
    end

    if M.enable(feature_name) then
        return true
    end

    return M.disable(feature_name)
end

---@param feature_name catharsis.features.Names
---@return boolean
function M.is_enabled(feature_name)
    local feature_handle = features_byname[feature_name]
    return feature_handle ~= nil and features_enabled[feature_handle] ~= nil
end

---@param feature catharsis.Feature
---@param bufs uinteger[]
---@param disabled true|nil
---@param handle uinteger
local function buf_enablement_change(feature, bufs, disabled, handle)
    local feature_disabled_bufs = feature.disabled_bufs
    for _, buf in ipairs(bufs) do
        feature_disabled_bufs[buf] = disabled
    end

    if features_disabled[handle] then
        return
    end

    local method = feature.spec.method
    local on_fn = disabled and feature.spec.on_buf_rm or feature.spec.on_buf_add
    for _, buf in ipairs(bufs) do
        if #lsp.get_clients({ bufnr = buf, method = method }) > 0 then
            on_fn(buf)
        end
    end
end

---@param feature_name catharsis.features.Names
---@param bufs uinteger[]
function M.enable_bufs(feature_name, bufs)
    local handle = features_byname[feature_name]
    if handle == nil then
        api.nvim_echo({ { "Feature does not exist", "WarningMsg" } }, true, {})
        return
    end

    local feature = features[handle]
    buf_enablement_change(feature, bufs, nil, handle)
end

---@param feature_name catharsis.features.Names
---@param bufs uinteger[]
function M.disable_bufs(feature_name, bufs)
    local handle = features_byname[feature_name]
    if handle == nil then
        api.nvim_echo({ { "Feature does not exist", "WarningMsg" } }, true, {})
        return
    end

    local feature = features[handle]
    buf_enablement_change(feature, bufs, true, handle)
end

---@param feature_name catharsis.features.Names
---@return [uinteger, boolean][]
function M.disabled_bufs_get(feature_name)
    local feature_handle = features_byname[feature_name]
    if feature_handle == nil then
        api.nvim_echo({ { "Feature does not exist", "WarningMsg" } }, true, {})
        return {}
    end

    return require("nvim-tools.table").keys(features[feature_handle].disabled_bufs)
end

---@param feature catharsis.Feature
---@param client_ids uinteger[]
---@param disabled true|nil
---@param handle uinteger
local function client_enablement_change(feature, client_ids, disabled, handle, f)
    local feature_disabled_client_ids = feature.disabled_client_ids
    local on_fn = disabled and feature.spec.on_client_rm or feature.spec.on_client_add
    for _, client_id in ipairs(client_ids) do
        feature_disabled_client_ids[client_id] = disabled
        on_fn(client_id)
    end

    if features_disabled[handle] then
        return
    end

    local method = feature.spec.method
    for _, client_id in ipairs(client_ids) do
        local client = lsp.get_client_by_id(client_id)
        if client and client:supports_method(method) then
            local bufs = client.attached_buffers
            for buf, _ in pairs(bufs) do
                if not feature.disabled_bufs[buf] then
                    f(feature, buf, client_id)
                end
            end
        end
    end
end

---@param feature_name catharsis.features.Names
---@param client_ids uinteger[]
function M.enable_clients(feature_name, client_ids)
    local handle = features_byname[feature_name]
    if handle == nil then
        api.nvim_echo({ { "Feature does not exist", "WarningMsg" } }, true, {})
        return
    end

    local feature = features[handle]
    client_enablement_change(feature, client_ids, nil, handle, function(feat, buf, _)
        feat.spec.on_buf_add(buf)
    end)
end

---@param feature_name catharsis.features.Names
---@param client_ids uinteger[]
function M.disable_clients(feature_name, client_ids)
    local handle = features_byname[feature_name]
    if handle == nil then
        api.nvim_echo({ { "Feature does not exist", "WarningMsg" } }, true, {})
        return
    end

    local feature = features[handle]
    client_enablement_change(feature, client_ids, true, handle, function(feat, buf, client_id)
        local method = feat.spec.method
        local buf_clients = lsp.get_clients({ bufnr = buf, method = method })
        require("nvim-tools.table").i_discard(buf_clients, function(client)
            return client.id == client_id
        end)

        if #buf_clients == 0 then
            feature.spec.on_buf_rm(buf)
        end
    end)
end

---@param feature_name catharsis.features.Names
---@return [uinteger, boolean][]
function M.disabled_clients_get(feature_name)
    local feature_handle = features_byname[feature_name]
    if feature_handle == nil then
        api.nvim_echo({ { "Feature does not exist", "WarningMsg" } }, true, {})
        return {}
    end

    return require("nvim-tools.table").keys(features[feature_handle].disabled_client_ids)
end

return M
