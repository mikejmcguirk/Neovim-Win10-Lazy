-- FUTURE:
-- https://github.com/kosayoda/nvim-lightbulb
-- Show icon where code actions are available, but would need more aesthetic icon

vim.pack.add({
    -- Multi-deps
    { src = "https://github.com/mike-jl/harpoonEx" },
    { src = "https://github.com/nvim-tree/nvim-web-devicons" },
    { src = "https://github.com/nvim-lua/plenary.nvim" },

    { src = "https://github.com/numToStr/Comment.nvim" },

    { src = "https://github.com/stevearc/conform.nvim" },

    { src = "https://github.com/folke/flash.nvim" },

    { src = "https://github.com/maxmx03/fluoromachine.nvim", version = "a5dc2cd" },

    -- Requires nvim-tree-web-devicons
    { src = "https://github.com/ibhagwan/fzf-lua" },

    { src = "https://github.com/lewis6991/gitsigns.nvim" },

    { src = "https://github.com/ThePrimeagen/harpoon", version = "harpoon2" },

    { src = "https://github.com/lukas-reineke/indent-blankline.nvim" },
    { src = "https://github.com/echasnovski/mini.indentscope" },

    -- { src = "https://github.com/folke/lazydev.nvim" },
    { src = "https://github.com/Jari27/lazydev.nvim" },

    -- Requires nvim-web-devicons, Harpoon, and HarpoonEx
    { src = "https://github.com/nvim-lualine/lualine.nvim" },
    { src = "https://github.com/linrongbin16/lsp-progress.nvim" },

    { src = "https://github.com/iamcco/markdown-preview.nvim" },

    { src = "https://github.com/windwp/nvim-autopairs" },

    { src = "https://github.com/hrsh7th/nvim-cmp" },
    { src = "https://github.com/hrsh7th/vim-vsnip" },
    { src = "https://github.com/hrsh7th/cmp-vsnip" },
    { src = "https://github.com/rafamadriz/friendly-snippets" },
    { src = "https://github.com/hrsh7th/cmp-nvim-lsp" },
    -- Show current function signature
    { src = "https://github.com/hrsh7th/cmp-nvim-lsp-signature-help" },
    { src = "https://github.com/hrsh7th/cmp-buffer" },
    -- From Nvim's built-in spell check },
    { src = "https://github.com/f3fora/cmp-spell" },
    { src = "https://github.com/FelipeLema/cmp-async-path" },
    { src = "https://github.com/ray-x/cmp-sql" },
    { src = "https://github.com/kristijanhusak/vim-dadbod-completion" },

    { src = "https://github.com/NvChad/nvim-colorizer.lua" },

    { src = "https://github.com/neovim/nvim-lspconfig" },

    { src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main" },

    { src = "https://github.com/kylechui/nvim-surround" },

    -- Depends on nvim-web-devicons
    { src = "https://github.com/nvim-tree/nvim-tree.lua" },

    { src = "https://github.com/windwp/nvim-ts-autotag" },

    -- Depends on plenary
    { src = "https://github.com/epwalsh/obsidian.nvim" },

    { src = "https://github.com/unblevable/quick-scope" },

    { src = "https://github.com/gbprod/substitute.nvim" },

    { src = "https://github.com/mbbill/undotree" },

    { src = "https://github.com/tpope/vim-abolish" },

    { src = "https://github.com/tpope/vim-dadbod" },
    { src = "https://github.com/kristijanhusak/vim-dadbod-ui" },

    { src = "https://github.com/tpope/vim-fugitive" },

    { src = "https://github.com/folke/zen-mode.nvim" },
}, { load = false })

local cached_git_data = {}
local started = false
local is_fetching = false
local pending_fetches = 0
local cached_spec

local function fetch_git_data(pack, callback)
    local cmd = { "git", "-C", pack.path, "log", "-1", "--format=%cd %H", "--date=short" }
    vim.system(cmd, { text = true }, function(result)
        local date = "Unknown"
        local commit = "Unknown"
        if result.code == 0 then
            local output = vim.trim(result.stdout)
            date, commit = output:match("(%d%d%d%d%-%d%d%-%d%d) (%w+)")
            date = date or "Unknown"
            commit = commit or "Unknown"
        end
        callback({ date = date, commit = commit })
    end)
end

local function cache_git_data(packs, sync)
    if sync then
        for _, pack in ipairs(packs) do
            local path_esc = vim.fn.shellescape(pack.path)
            local date_cmd = string.format("git -C %s log -1 --format=%%cd --date=short", path_esc)
            local date_output = vim.fn.system(date_cmd)
            local date = date_output:match("%d%d%d%d%-%d%d%-%d%d") or "Unknown"
            local commit_cmd = string.format("git -C %s rev-parse HEAD", path_esc)
            local commit = vim.fn.system(commit_cmd):gsub("\n$", "")
            cached_git_data[pack.spec.name] = { date = date, commit = commit }
        end
        is_fetching = false
    else
        started = true
        is_fetching = true
        pending_fetches = #packs
        for _, pack in ipairs(packs) do
            fetch_git_data(pack, function(data)
                cached_git_data[pack.spec.name] = data
                pending_fetches = pending_fetches - 1
                if pending_fetches == 0 then
                    is_fetching = false
                end
            end)
        end
    end
end

local function cache_spec()
    cached_spec = vim.pack.get()
end

local function rebuild_cache(opts)
    started = true
    is_fetching = true

    cache_spec()
    pending_fetches = #cached_spec
    if pending_fetches == 0 then
        is_fetching = false
        return
    end

    opts = opts or {}
    cache_git_data(cached_spec, opts.sync)
end

vim.keymap.set("n", "zqc", function()
    rebuild_cache()
end)

vim.api.nvim_create_autocmd({ "UIEnter" }, {
    group = vim.api.nvim_create_augroup("cache-packs", { clear = true }),
    callback = function()
        vim.defer_fn(function()
            rebuild_cache()
        end, 50)
    end,
})

local function wait_for_fetch()
    if not started then
        return false
    end

    if not is_fetching then
        return true
    end

    local result = vim.wait(10000, function()
        is_fetching = false
        return is_fetching
    end, 50)

    if not result then
        vim.notify("Timeout waiting for plugin data fetch", vim.log.levels.WARN)
    end

    return result
end

--- @param lines string[]
--- @param pack vim.pack.PlugData
--- @param opts? {add_blank: boolean}
local function add_base_lines(lines, pack, opts)
    table.insert(lines, string.format("%s", pack.spec.name))
    table.insert(lines, string.format("Source: %s (%s)", pack.spec.src, pack.spec.version))
    table.insert(lines, string.format("Path: %s", pack.path))

    local data = cached_git_data[pack.spec.name] or { date = "Unknown" }
    table.insert(lines, string.format("Last Updated: %s", data.date))

    opts = opts or {}
    if opts.add_blank then
        table.insert(lines, "")
    end

    return lines
end

local function new_giftwrap_buf(lines, name_lines)
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    local options = {
        { "bufhidden", "wipe" },
        { "buflisted", false },
        { "buftype", "nofile" },
        { "filetype", "giftwrap" },
        { "modifiable", false },
        { "modified", false },
        { "readonly", true },
        { "swapfile", false },
    }
    for _, option in pairs(options) do
        vim.api.nvim_set_option_value(option[1], option[2], { buf = bufnr })
    end

    local orig_tab_id = vim.api.nvim_get_current_tabpage()
    vim.keymap.set("n", "q", function()
        local exit_tab_id = orig_tab_id
        local tabpages = vim.api.nvim_list_tabpages()
        if not vim.tbl_contains(tabpages, orig_tab_id) then
            local tabnr = vim.fn.index(tabpages, vim.api.nvim_get_current_tabpage()) + 1
            local exit_tabnr = tabnr > 1 and tabnr - 1 or 2
            exit_tab_id = tabpages[exit_tabnr]
        end

        vim.api.nvim_buf_delete(bufnr, { force = true })
        vim.api.nvim_set_current_tabpage(exit_tab_id)
    end, { buffer = bufnr })

    local ns = vim.api.nvim_create_namespace("giftwrap")
    for _, hl in ipairs(name_lines) do
        vim.hl.range(bufnr, ns, hl.group, { hl.idx, 0 }, { hl.idx, -1 })
    end

    return bufnr
end

local function open_giftwrap_buf(bufnr)
    local cur_tab_count = #vim.api.nvim_list_tabpages()
    vim.cmd(cur_tab_count .. "tabnew")

    local new_tab_id = vim.api.nvim_list_tabpages()[cur_tab_count + 1]
    local tab_win = vim.api.nvim_tabpage_get_win(new_tab_id)
    local noname_buf = vim.api.nvim_win_get_buf(tab_win)

    vim.api.nvim_win_set_buf(tab_win, bufnr)
    vim.api.nvim_buf_delete(noname_buf, { force = true })
end

vim.keymap.set("n", "zqe", function()
    vim.api.nvim_echo({ { "Getting current plugin state..." } }, false, {})
    local has_cache = wait_for_fetch() and cached_spec and cached_git_data
    if not has_cache then
        rebuild_cache({ sync = true })
    end

    table.sort(cached_spec, function(a, b)
        return a.spec.name < b.spec.name
    end)

    local lines = {}
    local name_lines = {}
    for _, pack in ipairs(cached_spec) do
        local hl_group = pack.active and "DiagnosticHint" or "DiagnosticWarn"
        table.insert(name_lines, { idx = #lines, group = hl_group })
        lines = add_base_lines(lines, pack, { add_blank = true })
    end
    if lines[#lines] == "" then
        table.remove(lines)
    end

    vim.api.nvim_echo({ { "" } }, false, {})
    open_giftwrap_buf(new_giftwrap_buf(lines, name_lines))
end)

vim.keymap.set("n", "zqu", function()
    vim.notify("Getting current plugin state...")
    local has_cache = wait_for_fetch() and cached_spec and cached_git_data
    if not has_cache then
        rebuild_cache({ sync = true })
    end

    local old_git = {}
    for _, pack in ipairs(cached_spec) do
        old_git[pack.spec.name] = cached_git_data[pack.spec.name]
            or { commit = "", date = "Unknown" }
    end

    vim.notify("Updating vim.pack...")
    vim.pack.update({}, { force = true })
    cache_git_data(cached_spec, true)
    table.sort(cached_spec, function(a, b)
        return a.spec.name < b.spec.name
    end)

    local lines = {}
    local name_lines = {}
    for _, pack in ipairs(cached_spec) do
        local hl_group = pack.active and "DiagnosticHint" or "DiagnosticWarn"
        table.insert(name_lines, { idx = #lines, group = hl_group })
        lines = add_base_lines(lines, pack)

        local prev_state = old_git[pack.spec.name] or { commit = "", date = "Unknown" }
        local new_data = cached_git_data[pack.spec.name]
            or { commit = "Unknown", date = "Unknown" }
        local updated = new_data.commit ~= prev_state.commit

        if updated and prev_state.commit ~= "" then
            local path_esc = vim.fn.shellescape(pack.path)
            local log_str = 'git -C %s log %s..%s --pretty=format:"%%h %%ad %%s" --date=short'
            local log_cmd = string.format(log_str, path_esc, prev_state.commit, new_data.commit)
            local log_output = vim.fn.system(log_cmd)
            local commit_lines = vim.split(log_output, "\n", { trimempty = true })
            if #commit_lines > 0 then
                table.insert(lines, "New Commits:")
                for _, cl in ipairs(commit_lines) do
                    table.insert(lines, "  " .. cl)
                end
            end
        end

        table.insert(lines, "")
    end
    if lines[#lines] == "" then
        table.remove(lines)
    end

    vim.api.nvim_echo({ { "" } }, false, {})
    open_giftwrap_buf(new_giftwrap_buf(lines, name_lines))
end)

local ut = require("mjm.utils")

local function tbl_from_str(s)
    local t = {}
    for w in s:gmatch("%S+") do
        table.insert(t, w)
    end
    return t
end

vim.keymap.set("n", "zqd", function()
    local input = ut.get_input("Enter plugins to delete (space separated): ")
    if input == "" then
        return
    end

    local has_cache = wait_for_fetch() and cached_spec and cached_git_data
    if not has_cache then
        vim.notify("Rebuilding cache...", vim.log.levels.WARN)
        rebuild_cache({ sync = true })
        vim.api.nvim_echo({ { "" } }, false, {})
    end

    local t = tbl_from_str(input)
    vim.pack.del(t)

    local r = vim.tbl_filter(function(x)
        for _, p in pairs(cached_spec) do
            if x == p.spec.name and p.active then
                return true
            end
        end
        return false
    end, t)

    if #r <= 0 then
        return
    end
    local r_str = table.concat(r, ", ")
    vim.notify("Verify removal from installation spec: " .. r_str, vim.log.levels.INFO)
end)

vim.keymap.set("n", "zqr", function()
    local input = ut.get_input("Enter plugins to refresh (space separated): ")
    if input == "" then
        return
    end

    local has_cache = wait_for_fetch() and cached_spec and cached_git_data
    if not has_cache then
        vim.notify("Rebuilding cache...", vim.log.levels.WARN)
        rebuild_cache({ sync = true })
        vim.api.nvim_echo({ { "" } }, false, {})
    end

    local spec
    for _, p in pairs(cached_spec) do
        if p.spec.name == input then
            spec = p.spec
        end
    end

    vim.pack.del(tbl_from_str(input))

    if not spec then
        vim.notify("No plugin spec to re-install", vim.log.levels.INFO)
        return
    end
    vim.pack.add({ spec })
end)
