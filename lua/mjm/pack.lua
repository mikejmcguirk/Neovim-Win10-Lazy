local api = vim.api

local pack_spec = {
    -- Multi-deps
    { src = "https://github.com/nvim-tree/nvim-web-devicons" },
    { src = "https://github.com/nvim-lua/plenary.nvim" },

    { src = "https://github.com/saghen/blink.cmp", version = vim.version.range("1.*") },
    { src = "https://github.com/rafamadriz/friendly-snippets" },
    { src = "https://github.com/kristijanhusak/vim-dadbod-completion" },

    { src = "https://github.com/stevearc/conform.nvim" },

    -- Requires nvim-tree-web-devicons
    { src = "https://github.com/ibhagwan/fzf-lua" },

    { src = "https://github.com/lewis6991/gitsigns.nvim" },

    --- Requires plenary
    { src = "https://github.com/ThePrimeagen/harpoon", version = "harpoon2" },

    { src = "https://github.com/HakonHarnes/img-clip.nvim" },

    { src = "https://github.com/nvim-mini/mini.jump2d" },

    { src = "https://github.com/nvim-mini/mini.operators" },

    { src = "https://github.com/jake-stewart/multicursor.nvim" },

    { src = "https://github.com/windwp/nvim-autopairs" },

    { src = "https://github.com/kosayoda/nvim-lightbulb" },

    { src = "https://github.com/neovim/nvim-lspconfig" },

    { src = "https://github.com/kylechui/nvim-surround", version = vim.version.range("^3.0.0") },

    { src = "https://github.com/Dkendal/nvim-treeclimber" },

    { src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main" },

    { src = "https://github.com/nvim-treesitter/nvim-treesitter-textobjects", version = "main" },

    { src = "https://github.com/windwp/nvim-ts-autotag" },

    -- Requires mini.icons or nvim-tree/nvim-web-devicons
    { src = "https://github.com/stevearc/oil.nvim" },

    { src = "https://github.com/unblevable/quick-scope" },

    { src = "https://github.com/folke/snacks.nvim" },

    { src = "https://github.com/Wansmer/treesj" },

    { src = "https://github.com/tpope/vim-abolish" },

    { src = "https://github.com/tpope/vim-dadbod" },
    { src = "https://github.com/kristijanhusak/vim-dadbod-ui" },

    { src = "https://github.com/tpope/vim-fugitive" },

    { src = "https://github.com/andymass/vim-matchup" },
}

vim.pack.add(pack_spec, {})

vim.api.nvim_cmd({ cmd = "packadd", args = { "nvim.undotree" }, bang = true }, {})

-- TODO: Remove this once vim.pack can support local plugins

---@param pack string
---@return nil
local function custom_add(pack)
    api.nvim_cmd({ cmd = "packadd", args = { pack }, bang = true }, {})

    local packpath = vim.iter(api.nvim_list_runtime_paths()):find(function(path)
        local npath = vim.fs.normalize(path) ---@type string
        local basename = vim.fs.basename(npath) ---@type string
        if basename == pack then return npath end
    end) ---@type string|nil

    if not packpath then return end
    local fs = vim.uv.fs_scandir(packpath) ---@type uv.uv_fs_t|nil
    if not fs then return end

    while true do
        local name, type = vim.uv.fs_scandir_next(fs) ---@type string|nil, string
        if not name then break end
        if name == "doc" and type == "directory" then
            local doc_dir = vim.fs.joinpath(packpath, name) ---@type string
            local tag_file = vim.fs.joinpath(doc_dir, "tags") ---@type string

            vim.uv.fs_unlink(tag_file, function()
                vim.schedule(function()
                    ---@diagnostic disable-next-line: missing-fields
                    local magic = { file = false }
                    api.nvim_cmd({ cmd = "helptags", args = { doc_dir }, magic = magic }, {})
                end)
            end)

            break
        end
    end
end

custom_add("nvim-qf-rancher")

vim.keymap.set("n", "zqc", function()
    local inactive = vim.iter(vim.pack.get())
        :map(function(p)
            if not p.active then return p.spec.name end
            return nil
        end)
        :totable() ---@type string[]

    if #inactive == 0 then
        api.nvim_echo({ { "No inactive plugins", "" } }, false, {})
        return
    end

    vim.pack.del(inactive)
end)

vim.keymap.set("n", "zqd", function()
    local prompt = "Enter plugins to delete (space separated): " ---@type string
    local ok, result = require("mjm.utils").get_input(prompt) ---@type boolean, string
    if not ok then
        local msg = result or "Unknown error getting input" ---@type string
        vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
        return
    elseif result == "" then
        return
    end

    vim.pack.del(vim.split(result, " "))
end)

vim.keymap.set("n", "zqD", function()
    if vim.fn.confirm("Delete all plugins?", "&Yes\n&No", 2) ~= 1 then return end

    local plugins = vim.iter(vim.pack.get())
        :map(function(p)
            return p.spec.name
        end)
        :totable() ---@type string[]

    if #plugins == 0 then
        api.nvim_echo({ { "No plugins to delete", "" } }, false, {})
        return
    end

    vim.pack.del(plugins)
end)

vim.keymap.set("n", "zqu", function()
    vim.pack.update()
end)

-- https://github.com/neovim/neovim/commit/83f7d9851835d4ac5b92ddf689ad720914735712
-- TODO: Run the blink build script this way

-------------------------
--- POTENTIAL PLUGINS ---
-------------------------

-- https://github.com/rockerBOO/awesome-neovim - So many plugins out there
-- https://github.com/mrcjkb/rustaceanvim
-- Dap setup?
--    - https://github.com/tjdevries/config.nvim/blob/master/lua/custom/plugins/dap.lua
-- For dbs
--    - https://github.com/kndndrj/nvim-dbee
-- https://github.com/toppair/peek.nvim -- Markdown preview
-- Look at the multicursor plugin SteveArc uses. It seems to be the most mature project
-- Previewer for a lot of things: https://github.com/OXY2DEV/markview.nvim
