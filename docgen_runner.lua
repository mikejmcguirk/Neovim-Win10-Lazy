#!/usr/bin/env -S nvim -l

local sources = { "lua/docgen/test_file.lua" }
local output = "lua/docgen/test_file.txt"
local level = 1

require("docgen").generate(sources, output, level)
