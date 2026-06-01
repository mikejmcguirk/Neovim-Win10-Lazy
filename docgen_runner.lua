#!/usr/bin/env -S nvim -l

local sources = { { "lua/docgen/init.lua" }, { "lua/docgen/test_file.lua" } }
local output = "lua/docgen/test_file.txt"
local level = 1
local log_path = "lua/docgen"

require("docgen").generate(sources, output, level, log_path)
