---@type vim.lsp.Config
return {
    settings = {
        Lua = {
            diagnostics = { disable = { "trailing-space" } },
            -- Use stylua
            format = { enable = false },
            hint = { arrayIndex = "Enable" },
            runtime = { version = "LuaJIT" },
        },
    },
}

-- maria version
-- -- Install with
-- -- mac: brew install lua-language-server
-- -- Arch: pacman -S lua-language-server
--
-- ---@type vim.lsp.Config
-- return {
--     cmd = { 'lua-language-server' },
--     filetypes = { 'lua' },
--     root_markers = { '.luarc.json', '.luarc.jsonc' },
--     -- NOTE: These will be merged with the configuration file.
--     settings = {
--         Lua = {
--             completion = { callSnippet = 'Replace' },
--             -- Using stylua for formatting.
--             format = { enable = false },
--             hint = {
--                 enable = true,
--                 arrayIndex = 'Disable',
--             },
--             runtime = {
--                 version = 'LuaJIT',
--             },
--         },
--     },
-- }

-- echasnovski config
-- return {
--   on_attach = function(client, buf_id)
--     -- Reduce unnecessarily long list of completion triggers for better
--     -- 'mini.completion' experience
--     client.server_capabilities.completionProvider.triggerCharacters = { '.', ':', '#', '(' }
--
--     -- Override global "Go to source" mapping with dedicated buffer-local
--     local opts = { buffer = buf_id, desc = 'Lua source definition' }
--     vim.keymap.set('n', '<Leader>ls', Config.luals_unique_definition, opts)
--   end,
--   settings = {
--     Lua = {
--       runtime = { version = 'LuaJIT', path = vim.split(package.path, ';') },
--       diagnostics = {
--         -- Don't analyze whole workspace, as it consumes too much CPU and RAM
--         workspaceDelay = -1,
--       },
--       workspace = {
--         -- Don't analyze code from submodules
--         ignoreSubmodules = true,
--         -- Add Neovim's methods for easier code writing
--         library = { vim.env.VIMRUNTIME },
--       },
--       telemetry = { enable = false },
--     },
--   },
-- }
