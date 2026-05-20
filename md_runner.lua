#!/usr/bin/env -S nvim -l

-- local source = "lua/docgen/fzf-lua-readme.md"
-- local output = "lua/docgen/fzf-lua-readme.txt"
local source = "lua/docgen/basic_md_test.md"
local output = "lua/docgen/basic_md_test.txt"

require("docgen.md_vimdoc").start(source, output)
