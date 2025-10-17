require("mjm.global_settings")

------------------------------
--- Treesitter Interaction ---
------------------------------

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
            if file then require("mjm.utils").open_buf({ file = file }, { open = "vsplit" }) end
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

Map("n", "\\D", function()
    local cur_cfg = vim.diagnostic.config() or {}
    vim.diagnostic.config((not cur_cfg.virtual_lines) and diag_lines_cfg or diag_text_cfg)
end)

-- TODO/PR - Set pcmark when doing a diagnostic jump

local function on_bufreadpre()
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

    -- [D/]D cause my computer to lockup
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

vim.lsp.log.set_level(vim.log.levels.ERROR)

local lsp_mapping = require("mjm.lsp_mapping")
lsp_mapping.del_defaults()
local lsp_cmds = lsp_mapping.get_lsp_cmds()
local lsp_group = Augroup("lsp-autocmds", { clear = true })

Autocmd("LspAttach", {
    group = lsp_group,
    callback = function(ev)
        lsp_mapping.set_lsp_maps(ev, lsp_cmds)
    end,
})

Autocmd("LspDetach", {
    group = lsp_group,
    callback = function(ev)
        local buf = ev.buf ---@type integer
        local clients = vim.lsp.get_clients({ bufnr = buf }) ---@type vim.lsp.Client[]
        if not clients or vim.tbl_isempty(clients) then return end

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
