#!/usr/bin/env -S nvim -l

local sources = { "lua/docgen/init.lua", "lua/docgen/test_file.lua" }
local output = "lua/docgen/test_file.txt"
local level = 0

require("docgen").generate(sources, output, level)
