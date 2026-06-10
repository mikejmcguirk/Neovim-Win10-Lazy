#!/usr/bin/env -S nvim -l

---@type docgen.gen.source.Vimdoc[][]
local vs = {
    { path = "lua/docgen/init.lua", type = "luacats" },
    { path = "lua/docgen/test_keymaps.lua", type = "keymap" },
    { path = "lua/docgen/test_file.lua", type = "luacats" },
}

---@type docgen.gen.input.Readme[]
local rs = {
    { path = "lua/docgen/test_keymaps.lua", type = "keymap" },
}

---@type docgen.gen.input.Plugin[]
local ps = {
    { path = "lua/docgen/test_keymaps.lua", type = "plug_map" },
    {
        path = "lua/docgen/test_keymaps.lua",
        type = "default_map",
        cond = "config.set_default_keymaps ~= false",
    },
}

---@type docgen.gen.Opts
local opts = {
    log_level = 1,
    log_path = "lua/docgen",
    plugin_output_path = "lua/docgen/plugin.lua",
    readme_output_path = "lua/docgen/readme.md",
    vimdoc_credits_path = "lua/docgen/scripts/attribution.md",
    vimdoc_intro_path = "lua/docgen/scripts/intro.md",
    vimdoc_output_path = "lua/docgen/test_file.txt",
}
-- TODO: I think you name these like "vimdoc_output_txt_path" and "vimdoc_intro_md_path" to hint
-- at what filetype should be used
-- TODO: vimdoc > doc? vimdoc is long

require("docgen").gen_all(vs, rs, ps, opts)
