-- local api = vim.api
-- local lsp = vim.lsp

-- TODO: Allow this to work by buf. I want it to get rid of the refactor.rewrite lua_ls actions
-- DOCUMENT: That this is a string list of kinds to exclude. Note that typical examples are
-- "quickfix", "source.organizeImports", and "refactor"
-- DOCUMENT: The type here should be table<integer, string[]|fun(string):boolean>, where integer
-- is the buf and string[] is a list of titles, or a function to check
-- vim.g.action_lamp_filter = vim.g.action_lamp_filter or {}

-- DOCUMENT: When the ns is cleared
-- DOCUMENT: Write a demo showing display in the sign column

if not vim.g.action_lamp_default_autocmds then
    return
end

-- TODO: Working on the autocmds in the internal file

-- TODO: This file would be the /plugin, then the current lamp.lua would be init in /lua/lamp
-- This plugin should not be lazy loaded
-- TODO: Add health

-- MID: Would be cool to track context.version
-- - Starts at 0, which is easy enough
-- - Tougher: It doesn't seem to track undos/saves one-to-one. Unsure why

-- LOW: Would be interesting to cache results, but unsure how I can do so in a useful way. The
-- code as is builds the position based on the exact cursor position, and this can be relevant
-- such as with Lua function args. If we can't even cache by line, and cache is irrelevant on
-- each document change, then what's the point?

-- TODO: Do we love the name Action Lamp? I like "Lamp" but "Action Lamp" sounds a bit corny

-- DOCUMENT: For the two publicly exposed functions, document what events they are triggered on.
-- Note that CmdlineEnter needs a redraw
