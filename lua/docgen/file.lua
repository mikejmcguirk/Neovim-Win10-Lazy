local fn = vim.fn

local util = require("docgen.util")
local table_new = util.table_new

---@param path string
---@return string[] First segment is always "/"
local function split_path_get(path)
    local segments = table_new(4, 0) ---@type string[]
    segments[#segments + 1] = "/" -- Reduce contrivance upstream
    for segment in vim.gsplit(path, "/", { plain = true }) do
        if segment ~= "" then
            segments[#segments + 1] = segment
        end
    end

    return segments
end

---@param split_paths string[][]
---@param prefix_idx integer Index in each split_paths sub-table containing the prefix
local function prefix_and_tags_from_paths(split_paths, prefix_idx)
    local header_tags = table_new(#split_paths, 0) ---@type string[]
    for _, path in ipairs(split_paths) do
        local path_len = #path
        local tag_parts_len = (path_len - prefix_idx + 1) * 2 - 1
        local tag_parts = table_new(tag_parts_len, 0)

        tag_parts[1] = path[prefix_idx]
        local path_len_minus_one = path_len - 1
        for i = prefix_idx + 1, path_len_minus_one do
            tag_parts[#tag_parts + 1] = "-"
            tag_parts[#tag_parts + 1] = path[i]
        end

        local fname = path[path_len]
        if fname ~= "init.lua" then
            tag_parts[#tag_parts + 1] = "."
            tag_parts[#tag_parts + 1] = fn.fnamemodify(fname, ":r")
        end

        header_tags[#header_tags + 1] = table.concat(tag_parts)
    end

    local prefix = split_paths[1][prefix_idx]
    return prefix, header_tags
end

local M = {}

--- @param files string[] Absolute paths, normalized with forward slashes.
---         Assumes at least one is present.
--- @return string help_prefix
--- @return string[] header_tags
function M.header_tags_from_paths(files)
    local split_paths = table_new(#files, 0)
    for _, p in ipairs(files) do
        split_paths[#split_paths + 1] = split_path_get(p)
    end

    local path_len_min = math.huge
    for _, path in ipairs(split_paths) do
        path_len_min = math.min(path_len_min, #path)
    end

    -- Only check the |::h| component of the filename.
    local prefix_idx_max = path_len_min - 1
    -- A file is present in the file system root.
    if prefix_idx_max == 1 then
        return prefix_and_tags_from_paths(split_paths, prefix_idx_max)
    end

    local split_paths_len = #split_paths
    local first_path = split_paths[1]
    local prefix_idx = 1
    for i = 2, prefix_idx_max do
        local segment = first_path[i]
        local all = true
        for j = 2, split_paths_len do
            if split_paths[j][i] ~= segment then
                all = false
                break
            end
        end

        if all then
            prefix_idx = i
        else
            break
        end
    end

    return prefix_and_tags_from_paths(split_paths, prefix_idx)
end

return M
