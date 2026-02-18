#!/usr/bin/env luajit
-- make_emoji_ranges.lua
-- Usage: luajit make_emoji_ranges.lua <input.txt>
-- Creates <input>.lua in the same directory (overwrites if exists)

local input_path = arg[1]
if not input_path then
    io.stderr:write("Usage: luajit " .. arg[0] .. " <file-with-codepoint-lines>\n")
    os.exit(1)
end

-- Build output path: same directory, same basename, .lua extension
local dir = input_path:match("(.*/)") or "./"
local basename = input_path:match("([^/\\]+)$") or input_path
local name_no_ext = basename:match("(.+)%..+$") or basename
local output_path = dir .. name_no_ext .. ".lua"

local f = assert(io.open(input_path, "r"))

local points = {}

for line in f:lines() do
    line = line:match("^%s*(.-)%s*$")
    if line == "" then
        goto continue
    end

    local s, e = line:match("^([0-9A-Fa-f]+)%.%.([0-9A-Fa-f]+)$")
    if s and e then
        local start = assert(tonumber(s, 16))
        local stop = assert(tonumber(e, 16))
        if start > stop then
            start, stop = stop, start
        end
        for i = start, stop do
            table.insert(points, i)
        end
    else
        local n = assert(tonumber(line, 16))
        table.insert(points, n)
    end

    ::continue::
end

f:close()

-- dedup + sort
local seen = {}
local unique = {}
for _, v in ipairs(points) do
    if not seen[v] then
        seen[v] = true
        table.insert(unique, v)
    end
end
table.sort(unique)

-- merge into minimal ranges
local ranges = {}
if #unique > 0 then
    local cur_start = unique[1]
    local cur_end = unique[1]

    for i = 2, #unique do
        local v = unique[i]
        if v == cur_end + 1 then
            cur_end = v
        else
            table.insert(ranges, { cur_start, cur_end })
            cur_start = v
            cur_end = v
        end
    end
    table.insert(ranges, { cur_start, cur_end })
end

-- write the .lua file (overwrites)
local out = assert(io.open(output_path, "w"))

out:write("-- Auto-generated emoji ranges from " .. basename .. "\n")
out:write("-- Drop this table straight into your parser\n\n")
out:write("local emoji_ranges = {\n")

for _, r in ipairs(ranges) do
    out:write(string.format("  {0x%X, 0x%X},\n", r[1], r[2]))
end

out:write("}\n\n")
out:write("return emoji_ranges\n") -- so you can do: local emoji_ranges = dofile("...lua")

out:close()

print("Wrote " .. output_path .. " (" .. #ranges .. " ranges)")
