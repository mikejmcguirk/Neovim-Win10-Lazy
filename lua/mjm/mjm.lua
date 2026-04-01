local api = vim.api
local uv = vim.uv

_G.mjm = {}

mjm.v = {}
mjm.v.fmt_lhs = "<leader>o"
mjm.v.has_nerd_font = true

local gen_lcs = "extends:»,precedes:«,nbsp:␣,trail:⣿"
mjm.v.lcs = "tab:<->," .. gen_lcs
mjm.v.lcs_tab = "tab:   ," .. gen_lcs

mjm.v.shiftwidth = 4

-- Temp interfaces until https://github.com/neovim/neovim/issues/38420
mjm.opt = {}

---@param opt string
---@param flags_in string[]
---@param scope vim.api.keyset.option
function mjm.opt.flag_add(opt, flags_in, scope)
    local old = api.nvim_get_option_value(opt, scope) ---@type string
    local new = { old } ---@type string[]
    for _, flag in ipairs(flags_in) do
        if string.find(old, flag, 1, true) == nil then
            new[#new + 1] = flag
        end
    end

    api.nvim_set_option_value(opt, table.concat(new, ""), scope)
end

---@param opt string
---@param flags_out string[]
---@param scope vim.api.keyset.option
function mjm.opt.flag_rm(opt, flags_out, scope)
    local val = api.nvim_get_option_value(opt, scope) ---@type string
    for _, flag in ipairs(flags_out) do
        val = string.gsub(val, flag, "")
    end

    api.nvim_set_option_value(opt, val, scope)
end
-- MID: Is it better to split val into a table and filter on flags_out?

mjm.fs = {}
-- FUTURE: The code in the fs_stat calls is mostly redundant, but I don't want to make a
-- pre-mature generalization

local PERM_MASK = 511

---@param perm_bits integer
---@return string
local function mode_to_readable_perms(perm_bits)
    local perms = {}

    perms[1] = bit.band(perm_bits, 256) ~= 0 and "r" or "-"
    perms[2] = bit.band(perm_bits, 128) ~= 0 and "w" or "-"
    perms[3] = bit.band(perm_bits, 64) ~= 0 and "x" or "-"

    perms[4] = bit.band(perm_bits, 32) ~= 0 and "r" or "-"
    perms[5] = bit.band(perm_bits, 16) ~= 0 and "w" or "-"
    perms[6] = bit.band(perm_bits, 8) ~= 0 and "x" or "-"

    perms[7] = bit.band(perm_bits, 4) ~= 0 and "r" or "-"
    perms[8] = bit.band(perm_bits, 2) ~= 0 and "w" or "-"
    perms[9] = bit.band(perm_bits, 1) ~= 0 and "x" or "-"

    return table.concat(perms, "")
end

---@param buf integer|string
function mjm.fs.get_file_perms(buf)
    local ntb = require("nvim-tools.buf")
    local ok, full_bufname, r_err, r_hl = ntb.resolve_full_bufname(buf)
    if not ok then
        require("nvim-tools.ui").echo_err(false, r_err, r_hl)
        return
    end

    uv.fs_stat(full_bufname, function(err, stat)
        vim.schedule(function()
            local basename = vim.fs.basename(full_bufname)
            if err then
                local msg = "Cannot stat " .. basename .. ": " .. err
                api.nvim_echo({ { msg, "ErrorMsg" } }, true, {})
                return
            end

            local perm_bits = bit.band(stat.mode, PERM_MASK)
            local perms = mode_to_readable_perms(perm_bits)
            local octal = string.format("%03o", perm_bits)
            api.nvim_echo({
                { basename .. ": ", "Normal" },
                { perms, "Special" },
                { " (" .. octal .. ")", "Comment" },
            }, true, {})
        end)
    end)
end

---@param plus boolean|nil
---@param layer_bits integer|string
---@return string
local function get_chmod_arg(plus, layer_bits)
    local bits = layer_bits
    if type(layer_bits) == "string" then
        bits = tonumber(layer_bits, 8) -- base-8 = octal
        if not bits then
            error("Invalid octal permission: '" .. layer_bits)
        end
    end

    if bits < 0 or bits > PERM_MASK then
        error("Permission value out of range (0-777 octal)", 2)
    end

    local fmt = string.format("%03o", bits)
    return plus == nil and fmt or (plus and "+" or "-") .. fmt
end

---@param buf integer|string
---@param plus boolean|nil   -- true = +, false = -, nil = absolute
---@param layer_bits integer|string -- e.g. 111 (for +x/-x) or 755 (for absolute)
function mjm.fs.chmod(buf, plus, layer_bits)
    vim.validate("layer_bits", layer_bits, { "number", "string" })
    vim.validate("plus", plus, "boolean", true)
    local ntb = require("nvim-tools.buf")
    local ok, full_bufname, r_err, r_hl = ntb.resolve_full_bufname(buf)
    if not ok then
        require("nvim-tools.ui").echo_err(false, r_err, r_hl)
        return
    end

    if vim.fn.has("win32") == 1 then
        api.nvim_echo({ { "chmod is not supported on Windows" } }, true, {})
        return
    end

    local cmd = { "chmod", get_chmod_arg(plus, layer_bits), full_bufname }
    vim.system(cmd, { text = true }, function(result)
        if result.code ~= 0 then
            vim.schedule(function()
                local stderr = result.stderr and result.stderr:gsub("%s+$", "") or "(no output)"
                local msg = string.format("Error(%d): %s", result.code, stderr)
                api.nvim_echo({ { msg, "ErrorMsg" } }, true, {})
            end)

            return
        end

        uv.fs_stat(full_bufname, function(err, stat)
            vim.schedule(function()
                local basename = vim.fs.basename(full_bufname)
                if err then
                    local msg = "Cannot re-stat " .. basename .. ": " .. err
                    api.nvim_echo({ { msg, "ErrorMsg" } }, true, {})
                    return
                end

                local perm_bits = bit.band(stat.mode, PERM_MASK)
                local perms = mode_to_readable_perms(perm_bits)
                local octal = string.format("%03o", perm_bits)
                api.nvim_echo({
                    { "Success: " .. basename, "Normal" },
                    { " → ", "Normal" },
                    { perms, "Special" },
                    { " (" .. octal .. ")", "Comment" },
                }, true, {})
            end)
        end)
    end)
end

-- FUTURE: PR: vim.lsp.start should be able to take a vim.lsp.Config table directly
-- Problem: State of how project scope is defined in Neovim is evolving. The changes you would
-- make right now might be irrelevant to future project architecture (including deprecations of
-- current interfaces)
--
-- TRACKING ISSUES
-- https://github.com/neovim/neovim/issues/33214 - Project local data
-- https://github.com/neovim/neovim/issues/34622 - Decoupling root markers from LSP

-- NOTES:
-- https://github.com/neovim/neovim/pull/35182 - Rejected vim.project PR. Contains some thoughts
-- https://github.com/neovim/neovim/issues/8610 - General project concept thoughts
-- https://github.com/mfussenegger/nvim-dap/discussions/1530: Project root in the DAP context
-- exrc discussion: https://github.com/neovim/neovim/issues/33214#issuecomment-3159688873
-- https://github.com/neovim/neovim/pull/33771: Wildcards in fs.find
-- https://github.com/neovim/neovim/issues/33318: bcd
-- https://github.com/neovim/neovim/pull/33320: buf local cwd
-- https://github.com/neovim/neovim/pull/18506 (comment in here on project idea)
-- https://github.com/neovim/neovim/pull/31031 - lsp.config/lsp.enable

mjm.lsp = {}

---@param config vim.lsp.Config
---@param opts vim.lsp.start.Opts?
---@return integer? client_id
function mjm.lsp.start(config, opts)
    vim.validate("config", config, "table")
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local start_opts = vim.deepcopy(opts, true) ---@type vim.lsp.start.Opts
    start_opts.bufnr = vim._resolve_bufnr(start_opts.bufnr) ---@type integer
    if api.nvim_get_option_value("buftype", { buf = start_opts.bufnr }) ~= "" then
        return
    end

    start_opts.reuse_client = config.reuse_client
    ---@diagnostic disable-next-line: invisible
    start_opts._root_markers = config.root_markers
    if type(config.root_dir) == "function" then
        config.root_dir(start_opts.bufnr, function(root_dir)
            config = vim.deepcopy(config, true)
            config.root_dir = root_dir
            vim.schedule(function()
                return vim.lsp.start(config, start_opts)
            end)
        end)
    else
        return vim.lsp.start(config, start_opts)
    end
end
