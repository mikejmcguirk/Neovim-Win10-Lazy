-- NOTE: This file is overridden by Nvim's internal configuration.

return {
    runtime = {
        version = "LuaJIT",
    },
    -- runtime = {
    --     require_pattern = {
    --         "lua/?.lua",
    --         "lua/?/init.lua",
    --         "?/lua/?.lua",
    --         "?/lua/?/init.lua",
    --     },
    -- },
    -- diagnostics = {
    --     disable = { "unnecessary-if" },
    -- },
    strict = {
        arrayIndex = false,
    },
    workspace = {
        library = {
            "$VIMRUNTIME",
            -- "$HOME/.local/share/nvim/lazy",
        },
        ignoreGlobs = { "**/*_spec.lua" },
    },
}

-- MID: For whatever reason, this is the only way I can get it to pick up the vim runtime.
-- Maybe for the JSON version you need to export it as a global env variable, but it doesn't work
-- there even if I enter the path manually. And if I do vim.env.VIMRUNTIME in LSP config, it
-- fails to load (code lenses never display), but goto definition just hangs forever. This feels
-- like some kind of underlying issue that's worth understanding.
