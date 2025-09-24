-- LOW: SSH clipboard config
-- https://github.com/tjdevries/config.nvim/blob/master/plugin/clipboard.lua
-- MAYBE: vim.g.deprecation_warnings = true -- Pre-silence deprecation warnings

local set_group = Augroup("set-group", { clear = true })
local global_scope = { scope = "global" }
local noremap = { noremap = true }

-------------------
--- Global Vars ---
-------------------

Gset("no_plugin_maps", 1)

--- :h standard-plugin-list
--- Disabling these has a non-trivial effect on startup time
--- LOW: No need to change now, but the 2html plugin appears to have been re-written in Lua, and
--- on load only creates an autocmd. Might be useful
Gset("loaded_2html_plugin", 1)
Gset("did_install_default_menus", 1)
Gset("loaded_gzip", 1)
Gset("loaded_man", 1)
Gset("loaded_matchit", 1)
Gset("loaded_matchparen", 1)
Gset("loaded_netrw", 1)
Gset("loaded_netrwPlugin", 1)
Gset("loaded_netrwSettings", 1)
Gset("loaded_remote_plugins", 1)
Gset("loaded_shada_plugin", 1)
Gset("loaded_spellfile_plugin", 1)
Gset("loaded_tar", 1)
Gset("loaded_tarPlugin", 1)
Gset("loaded_tutor_mode_plugin", 1)
Gset("loaded_zip", 1)
Gset("loaded_zipPlugin", 1)

-- I have xsel on my system
local termfeatures = vim.g.termfeatures or {}
termfeatures.osc52 = false
Gset("termfeatures", termfeatures)

Map({ "n", "x" }, "<Space>", "<Nop>")
Gset("mapleader", " ")
Gset("maplocalleader", " ")

-----------------------
-- Internal Behavior --
-----------------------

SetOpt("fileformats", "unix,dos", global_scope)
SetOpt("jop", "clean,view", global_scope)

SetOpt("swapfile", false, global_scope)
SetOpt("undofile", true, global_scope)
SetOpt("updatetime", 300, global_scope)

-- :h 'sd'
SetOpt("sd", [[<0,'100,/0,:1000,h]], global_scope)

-- Unsimplify mappings
-- See :h <tab> and https://github.com/neovim/neovim/pull/17932
-- NOTE: For this to work in Tmux, that config has to be handled separately
ApiMap("n", "<C-i>", "<C-i>", noremap)
ApiMap("n", "<tab>", "<tab>", noremap)
ApiMap("n", "<C-m>", "<C-m>", noremap)
ApiMap("n", "<cr>", "<cr>", noremap)
ApiMap("n", "<C-[>", "<C-[>", noremap)
ApiMap("n", "<esc>", "<esc>", noremap)

--------
-- UI --
--------

SetOpt("mouse", "", global_scope)

SetOpt("backspace", "indent,eol,nostop", global_scope)
SetOpt("mps", GetOpt("mps", global_scope) .. ",<:>", { scope = "global" })

--- W - Don't overwrite readonly files
--- Z - Don't reset readonly with W!
SetOpt("cpo", GetOpt("cpo", global_scope) .. "WZ", { scope = "global" })
SetOpt("modelines", 1, global_scope)

SetOpt("ignorecase", true, global_scope)
SetOpt("smartcase", true, global_scope)
-- Don't want screen shifting while entering search/subsitute patterns
SetOpt("incsearch", false, global_scope)

SetOpt("selection", "old", global_scope)
SetOpt("so", Scrolloff_Val, global_scope)

SetOpt("splitbelow", true, global_scope)
SetOpt("splitright", true, global_scope)
-- For some reason, uselast needs to be manually set globally
SetOpt("switchbuf", "useopen,uselast", global_scope)

--------------------------
--- Text Input/Display ---
--------------------------

SetOpt("tabstop", 4, global_scope)
SetOpt("softtabstop", 4, global_scope)
SetOpt("shiftwidth", 4, global_scope)
SetOpt("expandtab", true, global_scope)
SetOpt("shiftround", true, global_scope)

---------------------
-- Buffer Behavior --
---------------------

-- https://github.com/neovim/neovim/pull/35536
-- https://github.com/neovim/neovim/issues/35575
-- Issue is better after this pull request, but not resolve. In this file I can see some
-- global scope settings still whited out.
-- TODO: Test this again with a minimal config
-- SetOpt("wrap", false, global_scope)
-- For fts where opt_local wrap is true
SetOpt("breakindent", true, global_scope)
SetOpt("linebreak", true, global_scope)
SetOpt("smartindent", true, global_scope)

local dict = vim.fn.expand("~/.local/bin/words/words_alpha.txt")
SetOpt("dictionary", dict, global_scope)
SetOpt("spell", false, global_scope)
SetOpt("spelllang", "en_us", global_scope)

----------------
-- Aesthetics --
----------------

SetOpt("fcs", "eob: ", global_scope)

local blink_setting = "blinkon1-blinkoff1"
local norm_cursor = "n:block" .. blink_setting
local ver_cursor = "i-sm-c-ci-t:ver100-" .. blink_setting
local hor_cursor = "o-v-ve-r-cr:hor100-" .. blink_setting
local gcr = norm_cursor .. "," .. ver_cursor .. "," .. hor_cursor
SetOpt("guicursor", gcr, global_scope)

--- a - All abbreviations
--- s - No search hit top/bottom messages
--- I - No intro message
--- W - No "written" notifications
SetOpt("shm", GetOpt("shm", global_scope) .. "asIW", { scope = "global" })

SetOpt("ru", false, global_scope)

vim.filetype.add({ filename = { [".bashrc_custom"] = "sh" } })

--- @param event string|string[]
--- @param opt string
--- @param val any
local function autoset_winopt(event, opt, val)
    Autocmd(event, {
        group = set_group,
        callback = function()
            SetOpt(opt, val, { win = vim.api.nvim_get_current_win() })
        end,
    })
end

------------------
--- Cursorline ---
------------------

SetOpt("cul", true, global_scope)
autoset_winopt("WinEnter", "cul", true)
autoset_winopt("WinLeave", "cul", false)

----------------------
--- Format Options ---
----------------------

-- See help fo-table
-- Since multiple runtime ftplugin files set formatoptions, correct here
Autocmd({ "FileType" }, {
    group = set_group,
    pattern = "*",
    callback = function(ev)
        local fo = GetOpt("fo", { buf = ev.buf })
        local new_fo = string.gsub(fo, "o", "")
        SetOpt("fo", new_fo, { buf = ev.buf })
    end,
})

-----------------
--- Listchars ---
-----------------

SetOpt("list", true, global_scope)
SetOpt("lcs", "tab:<->,extends:»,precedes:«,nbsp:␣,trail:⣿", global_scope)
autoset_winopt("InsertEnter", "list", true)
autoset_winopt("InsertLeave", "list", false)

------------------
--- Numberline ---
------------------

-- On my monitors, for files under 10k lines, a centered vsplit will be on the color column
SetOpt("nu", true, global_scope)
SetOpt("rnu", true, global_scope)
SetOpt("cc", "100", global_scope)
SetOpt("nuw", 5, global_scope)
SetOpt("scl", "yes:1", global_scope)
Autocmd("CmdlineEnter", {
    group = set_group,
    callback = function()
        SetOpt("rnu", false, { win = vim.api.nvim_get_current_win() })
        if not vim.tbl_contains({ "@", "-" }, vim.v.event.cmdtype) then
            vim.cmd("redraw")
        end
    end,
})

-- LOW: Would this work with BufWinEnter instead?
-- Need BufLeave/BufEnter for this to work when going into help
autoset_winopt({ "WinLeave", "BufLeave" }, "rnu", false)
autoset_winopt({ "WinEnter", "CmdlineLeave", "BufEnter" }, "rnu", true)

----------------------
-- Autocmd Controls --
----------------------

Autocmd("BufWinEnter", {
    group = set_group,
    desc = "Go to the last location when opening a buffer",
    callback = function(ev)
        local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
        local line_count = vim.api.nvim_buf_line_count(ev.buf)
        if mark[1] < 1 or mark[1] > line_count then
            return
        end

        Cmd({ cmd = "normal", args = { 'g`"zz' } }, {})
    end,
})

local clear_conditions = {
    "BufEnter",
    "CmdlineEnter",
    -- "InsertEnter",
    "RecordingEnter",
    "TabLeave",
    "TabNewEntered",
    "WinEnter",
    "WinLeave",
} ---@type string[]

Autocmd(clear_conditions, {
    group = set_group,
    pattern = "*",
    -- The highlight state is saved and restored when autocmds are triggered, so
    -- schedule_wrap is used to trigger nohlsearch aftewards
    -- See nohlsearch() help
    callback = vim.schedule_wrap(function()
        vim.cmd.nohlsearch()
    end),
})

----------------

-- vim.opt.lazyredraw = false -- Causes unpredictable problems
-- vim.opt.startofline = false -- Makes gg/G feel weird
-- vim.opt.winborder = "single" -- Sets arbitrary border around Zen mode display

-------------------
--- Colorscheme ---
-------------------

Gset("c_syntax_for_h", true)
Map("n", "gT", function()
    vim.api.nvim_cmd({ cmd = "Inspect" }, {})
end)

Cmd({ cmd = "hi", args = { "clear" } }, {})
if vim.g.syntax_on == 1 then
    Cmd({ cmd = "syntax", args = { "reset" } }, {})
end

require("mjm.colorscheme").set_highlights()

--- @param hl_query vim.treesitter.Query
--- @return nil
local ts_nop_all = function(hl_query)
    -- Doesn't capture injections, so just sits on top of comment
    hl_query.query:disable_capture("comment.documentation")

    -- Allow to default to normal
    hl_query.query:disable_capture("punctuation.delimiter")
    hl_query.query:disable_capture("variable")
    hl_query.query:disable_capture("variable.member")

    -- Extraneous without an LSP to analyze scope
    hl_query.query:disable_capture("variable.parameter")
end

---------
-- Lua --
---------

-- Can't disable at the token level because it's the root of function globals
SetHl(0, "@lsp.type.function.lua", {})

-- MAYBE: Disable the default highlight constants and use a custom query so we aren't grabbing
-- stuff like require
Autocmd("FileType", {
    group = vim.api.nvim_create_augroup("lua-disable-captures", { clear = true }),
    pattern = "lua",
    once = true,
    callback = function()
        --- @type vim.treesitter.Query?
        local hl_query = vim.treesitter.query.get("lua", "highlights")
        if not hl_query then
            return
        end

        ts_nop_all(hl_query)

        hl_query.query:disable_capture("function") -- Confusing when functions are used as vars
        -- Don't need to distinguish function builtins
        hl_query.query:disable_capture("function.builtin")
        hl_query.query:disable_capture("module.builtin")
        hl_query.query:disable_capture("property")
        hl_query.query:disable_capture("punctuation.bracket")

        vim.api.nvim_del_augroup_by_name("lua-disable-captures")
    end,
})

local token_nop_lua = {
    "comment", -- Treesitter handles
    "method", -- Treesitter handles
    -- TODO: Check this with a class like the TSHighlighter
    "property", -- Can just be fg
} --- @type string[]

------------
-- Python --
------------

Autocmd("FileType", {
    group = vim.api.nvim_create_augroup("python-disable-captures", { clear = true }),
    pattern = "python",
    once = true,
    callback = function()
        --- @type vim.treesitter.Query?
        local hl_query = vim.treesitter.query.get("python", "highlights")
        if not hl_query then
            return
        end

        ts_nop_all(hl_query)
        hl_query.query:disable_capture("punctuation.bracket")
        hl_query.query:disable_capture("string.documentation") -- Just masks string
    end,
})

----------
-- Rust --
----------

Autocmd("FileType", {
    group = vim.api.nvim_create_augroup("rust-disable-captures", { clear = true }),
    pattern = "rust",
    once = true,
    callback = function()
        --- @type vim.treesitter.Query?
        local hl_query = vim.treesitter.query.get("rust", "highlights")
        if not hl_query then
            return
        end

        ts_nop_all(hl_query)
        -- Have to keep punctuation.bracket to mask operator highlights
        hl_query.query:disable_capture("type.builtin") -- Don't need to distinguish this

        vim.api.nvim_del_augroup_by_name("rust-disable-captures")
    end,
})

Autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("rust-disable-captures-lsp", { clear = true }),
    callback = function(ev)
        if vim.api.nvim_get_option_value("filetype", { buf = ev.buf }) ~= "rust" then
            return
        end

        --- @type vim.treesitter.Query?
        local hl_query = vim.treesitter.query.get("rust", "highlights")
        if not hl_query then
            return
        end

        -- rust_analyzer contains built-in highlights for multiple types that should be
        -- left active for doc comments. If an LSP attaches, disable the TS queries
        hl_query.query:disable_capture("constant.builtin")
        hl_query.query:disable_capture("function")
        hl_query.query:disable_capture("function.call")
        hl_query.query:disable_capture("function.macro")
        hl_query.query:disable_capture("_identifier")
        hl_query.query:disable_capture("keyword.debug")
        hl_query.query:disable_capture("keyword.exception")
        hl_query.query:disable_capture("string")
        hl_query.query:disable_capture("type")

        vim.api.nvim_del_augroup_by_name("rust-disable-captures-lsp")
    end,
})

local token_nop_rust = {
    "comment",
    "const",
    "namespace", --- Handle with custom TS queries
    "selfKeyword",
    "property", --- Default to Normal
} --- @type string[]

------------
-- vimdoc --
------------

-- I'm not sure this was actually useful
-- Run eagerly to avoid inconsistent preview window appearance
-- local vimdoc_query = vim.treesitter.query.get("vimdoc", "highlights")
-- if vimdoc_query then ts_nop_all(vimdoc_query) end

----------------------------
-- Semantic Token Removal --
----------------------------

local token_filter = {
    ["lua_ls"] = token_nop_lua,
    ["rust_analyzer"] = token_nop_rust,
} --- @type {string: string[]}

Autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("token-filter", { clear = true }),
    callback = function(ev)
        local client = vim.lsp.get_client_by_id(ev.data.client_id) --- @type vim.lsp.Client?
        if (not client) or not client.server_capabilities.semanticTokensProvider then
            return
        end

        local found_client_name = false
        for k, _ in pairs(token_filter) do
            if k == client.name then
                found_client_name = true
                break
            end
        end

        if not found_client_name then
            return
        end

        --- @type lsp.SemanticTokensLegend
        local legend = client.server_capabilities.semanticTokensProvider.legend
        local new_tokenTypes = {} --- @type string[]

        for _, typ in ipairs(legend.tokenTypes) do
            if not vim.tbl_contains(token_filter[client.name], typ) then
                table.insert(new_tokenTypes, typ)
            else
                -- The builtin semantic token handler checks the token names for truthiness
                -- Set to false to return a falsy value and skip position calculation, without
                -- mis-aligning the legend indexing
                table.insert(new_tokenTypes, false)
            end
        end

        legend.tokenTypes = new_tokenTypes
        vim.lsp.semantic_tokens.force_refresh(ev.buf)
    end,
})

------------------------------
--- Treesitter Interaction ---
------------------------------

-- TODO: When treesitter is on, [s]s work for some buffers but not others. This feels like
-- intended behavior, but how to modify?

Map("n", "gtt", function()
    if vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] then
        vim.treesitter.stop()
    else
        vim.treesitter.start()
    end
end)

Map("n", "gti", function()
    vim.api.nvim_cmd({ cmd = "InspectTree" }, {})
end)

Map("n", "gtee", function()
    vim.api.nvim_cmd({ cmd = "EditQuery" }, {})
end)

--- @param query_group string
--- @return nil
--- Lifted from the old TS Master Branch
local function edit_query_file(query_group)
    local lang = vim.api.nvim_get_option_value("filetype", { buf = 0 })
    local files = vim.treesitter.query.get_files(lang, query_group, nil)
    if #files == 0 then
        vim.api.nvim_echo({ { "No query file found", "" } }, false, {})
        return
    elseif #files == 1 then
        require("mjm.utils").open_buf({ file = files[1] }, { open = "vsplit" })
    else
        vim.ui.select(files, { prompt = "Select a file:" }, function(file)
            if file then
                require("mjm.utils").open_buf({ file = file }, { open = "vsplit" })
            end
        end)
    end
end

Map("n", "gteo", function()
    edit_query_file("folds")
end)

Map("n", "gtei", function()
    edit_query_file("highlights")
end)

Map("n", "gten", function()
    edit_query_file("indents")
end)

Map("n", "gtej", function()
    edit_query_file("injections")
end)

Map("n", "gtex", function()
    edit_query_file("textobjects")
end)

-------------------
--- Diagnostics ---
-------------------

local diag_main_cfg = {
    float = { source = true, border = Border },
    severity_sort = true,
} ---@type table

local virt_text_cfg = {
    virtual_lines = false,
    virtual_text = {
        current_line = true,
    },
} ---@type table

local virt_lines_cfg = {
    virtual_lines = { current_line = true },
    virtual_text = false,
} ---@type table

local diag_text_cfg = vim.tbl_extend("force", diag_main_cfg, virt_text_cfg)
local diag_lines_cfg = vim.tbl_extend("force", diag_main_cfg, virt_lines_cfg)
vim.diagnostic.config(diag_text_cfg)

ApiMap("n", "\\d", "<nop>", {
    noremap = true,
    callback = function()
        vim.diagnostic.enable(not vim.diagnostic.is_enabled())
    end,
})

-- TODO: map to show err only or top severity only
-- TODO: map to show config status. should apply to other \ maps as well
Map("n", "\\D", function()
    local cur_cfg = vim.diagnostic.config() or {}
    vim.diagnostic.config((not cur_cfg.virtual_lines) and diag_lines_cfg or diag_text_cfg)
end)

local function on_bufreadpre()
    -- TODO: Is it possible to get out of the current top_severity function? The problem is it
    -- doesn't actually save us a diagnostic_get in this case

    Map("n", "[<C-d>", function()
        vim.diagnostic.jump({
            count = -vim.v.count1,
            severity = require("mjm.utils").get_top_severity({ buf = 0 }),
        })
    end)

    Map("n", "]<C-d>", function()
        vim.diagnostic.jump({
            count = vim.v.count1,
            severity = require("mjm.utils").get_top_severity({ buf = 0 }),
        })
    end)

    -- For whatever reason, [D/]D on my computer cause Neovim to lock up. Even when just using
    -- large numbers for count, they don't reliably find the top and bottom diag. Instead, just
    -- search for the first/last diag manually and jump to it
    local function get_first_or_last_diag(opts)
        opts = opts or {}
        local diagnostics = opts.severity and vim.diagnostic.get(0, { severity = opts.severity })
            or vim.diagnostic.get(0)

        if #diagnostics == 0 then
            vim.api.nvim_echo({ { "No diagnostics in current buffer", "" } }, false, {})
            return
        end

        table.sort(diagnostics, function(a, b)
            if a.lnum ~= b.lnum then
                return a.lnum < b.lnum
            elseif a.severity ~= b.severity then
                return a.severity < b.severity
            elseif a.end_lnum ~= b.end_lnum then
                return a.end_lnum < b.end_lnum
            elseif a.col ~= b.col then
                return a.col < b.col
            else
                return a.end_col < b.end_col
            end
        end)

        return opts.last and diagnostics[#diagnostics] or diagnostics[1]
    end

    Map("n", "[D", function()
        local diagnostic = get_first_or_last_diag()
        if diagnostic then
            vim.diagnostic.jump({
                diagnostic = diagnostic,
            })
        end
    end)

    Map("n", "]D", function()
        local diagnostic = get_first_or_last_diag({ last = true })
        if diagnostic then
            vim.diagnostic.jump({
                diagnostic = diagnostic,
            })
        end
    end)

    -- TODO: Potentially better case for using the updated severity filtering

    Map("n", "[<M-d>", function()
        local severity = require("mjm.utils").get_top_severity({ buf = 0 })
        local diagnostic = get_first_or_last_diag({ severity = severity })
        if diagnostic then
            vim.diagnostic.jump({
                diagnostic = diagnostic,
            })
        end
    end)

    Map("n", "]<M-d>", function()
        local severity = require("mjm.utils").get_top_severity({ buf = 0 })
        local diagnostic = get_first_or_last_diag({ severity = severity, last = true })
        if diagnostic then
            vim.diagnostic.jump({
                diagnostic = diagnostic,
            })
        end
    end)
end

Autocmd({ "BufReadPre", "BufNewFile" }, {
    group = Augroup("diag-keymap-setup", { clear = true }),
    once = true,
    callback = function()
        on_bufreadpre()
        vim.api.nvim_del_augroup_by_name("diag-keymap-setup")
    end,
})

---------
-- LSP --
---------

-- TODO: Consider getting a C lsp for reading code. I think clang is the one everyone uses
-- LOW: Weird Issue where workspace update is triggered due to FzfLua require, and Semantic
-- Tokens do not consistently refresh afterwards

vim.lsp.log.set_level(vim.log.levels.ERROR)

local lsp_mapping = require("mjm.lsp_mapping")
lsp_mapping.del_defaults()
local lsp_cmds = lsp_mapping.get_lsp_cmds()

Autocmd("LspAttach", {
    group = set_group,
    callback = function(ev)
        lsp_mapping.set_lsp_maps(ev, lsp_cmds)
    end,
})

Autocmd("LspDetach", {
    group = set_group,
    callback = function(ev)
        local buf = ev.buf ---@type integer
        local clients = vim.lsp.get_clients({ bufnr = buf }) ---@type vim.lsp.Client[]
        if not clients or vim.tbl_isempty(clients) then
            return
        end

        for _, client in pairs(clients) do
            local attached_bufs = vim.tbl_filter(function(buf_nbr)
                return buf_nbr ~= buf
            end, vim.tbl_keys(client.attached_buffers)) ---@type unknown[]

            if vim.tbl_isempty(attached_bufs) then
                vim.schedule(function()
                    vim.lsp.stop_client(client.id)
                end)
            end
        end
    end,
})

-- Configs are in after/lsp
vim.lsp.enable({
    --- Bash --
    "bashls",
    --- Go ---
    "golangci_lint_ls",
    "gopls",
    --- HTML/CSS ---
    "cssls",
    "html",
    --- Lua ---
    -- FUTURE: This might be the way
    -- https://old.reddit.com/r/neovim/comments/1mdtr4g/emmylua_ls_is_supersnappy/
    "lua_ls",
    --- Python ---
    -- Ruff is not feature-complete enough to replace pylsp
    "pylsp",
    "ruff",
    --- Rust ---
    "rust_analyzer",
    --- Toml ---
    "taplo",
})
