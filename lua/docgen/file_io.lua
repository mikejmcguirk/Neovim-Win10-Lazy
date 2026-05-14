local fn = vim.fn
local fs = vim.fs

local util = require("docgen.util")
local list_slice = util.list_slice

---@param path string
---@return string[]
local function split_path_get(path)
    local parts = {} ---@type string[]
    for part in vim.gsplit(path, "/", { plain = true }) do
        if part ~= "" then
            parts[#parts + 1] = part
        end
    end

    return parts
end

local M = {}

--- @param files string[]
--- @return string common_dir
--- @return string[] rel_paths
local function get_common_dir_and_rel_paths(files)
    -- TODO: I think you push up this check and error if there are no files.
    if not files or #files == 0 then
        return vim.fn.getcwd(), {}
    end

    -- TODO: This should be pre-created and validated, both in terms of the table data and that
    -- the files actually exist.
    local abs_paths = {}
    for _, f in ipairs(files) do
        table.insert(abs_paths, fs.normalize(fn.fnamemodify(f, ":p")))
    end

    local split_paths = {}
    for _, p in ipairs(abs_paths) do
        split_paths[#split_paths + 1] = split_path_get(p)
    end

    local split_paths_len_min = math.huge
    for _, path in ipairs(split_paths) do
        -- Subtract one so the filename isn't part of the calculation.
        split_paths_len_min = math.min(split_paths_len_min, #path - 1)
    end

    -- TODO: Everything is a file directly inside the file system root
    -- Rather than a silly place holder, it should just tell you this has happened.
    if split_paths_len_min == 0 then
        return "/", {}
    end

    local split_paths_len = #split_paths
    local first_path = split_paths[1]
    local common_root_level = 0
    for i = 1, split_paths_len_min do
        local part = first_path[i]
        local is_common = true
        for j = 2, split_paths_len do
            if split_paths[j][i] ~= part then
                is_common = false
                break
            end
        end

        if is_common then
            common_root_level = i
        else
            break
        end
    end

    -- TODO: Not sure this is right because we want the rel paths by themselves so we can
    -- convert them into the middle help tag part. Unsure why we'd do another split later
    -- when we can just keep the last part of the common path, so you'd do like
    -- split_paths[1][common_root_level] without the subtraction to get the help_prefix.

    -- TODO: Special case where there is only one file, in which case the loop above would
    -- also grab the filename, which we certainly don't want.

    -- TODO: If we could snip off the file extensions here that would be good. Would save a
    -- string op later. Conceptually though, you would have to call this function something
    -- like "file paths to help tag parts". So that way it was clear.

    -- Preserve the top level common dir name.
    common_root_level = common_root_level - 1

    if common_root_level == 0 then
        -- TODO: Only common root is the file system root
        return "/", {}
    end

    local rel_paths = {}
    for _, path in ipairs(split_paths) do
        rel_paths[#rel_paths + 1] = table.concat(path, "/", common_root_level)
    end

    -- if fn.has("win32") ~= 1 then
    --     for i = 1, #rel_paths do
    --         rel_paths[i] = "/" ..
    --     end
    -- end

    -- Build the absolute common directory
    local common_parts = {}
    for i = 1, common_root_level do
        table.insert(common_parts, split_paths[1][i])
    end

    local common_dir
    if #common_parts == 0 then
        common_dir = "/"
    elseif common_parts[1]:match("^[a-zA-Z]:$") then
        -- Windows drive letter (e.g. "C:")
        common_dir = table.concat(common_parts, "/")
    else
        common_dir = "/" .. table.concat(common_parts, "/")
    end

    -- Build relative paths from the common directory
    for k, parts in ipairs(split_paths) do
        local rel_parts = {}
        for i = common_root_level + 1, #parts do
            table.insert(rel_parts, parts[i])
        end
        local rel = table.concat(rel_parts, "/")
        if rel == "" then
            -- Only happens for the identical-files case (which we already trimmed)
            -- Fallback just in case
            rel = vim.fn.fnamemodify(abs_paths[k], ":t")
        end
        table.insert(rel_paths, rel)
    end

    return common_dir, rel_paths
end

-- TODO: Dummy code
local files = {
    "foo/bar/buzz.lua",
    "foo/bazz/bar/bill.lua",
    "foo/fizz.lua",
    -- can be relative or absolute, Neovim handles both
}

-- TODO: Dummy code
local common_dir, rel_paths = get_common_dir_and_rel_paths(files)

-- TODO: Dummy code
print("Common directory:", common_dir)
for _, rel in ipairs(rel_paths) do
    print("  →", rel)
end

return M
