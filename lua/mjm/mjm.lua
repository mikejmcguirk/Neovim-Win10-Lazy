local api = vim.api

_G.mjm = {}

mjm.v = {}
mjm.v.has_nerd_font = true

mjm.v.shiftwidth = 4

mjm.fs = {}

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
---@return nil
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
    ---@diagnostic disable-next-line: invisible, access-invisible
    start_opts._root_markers = config.root_markers
    if type(config.root_dir) == "function" then
        config.root_dir(start_opts.bufnr, function(root_dir)
            config = vim.deepcopy(config, true)
            config.root_dir = root_dir
            vim.schedule(function()
                vim.lsp.start(config, start_opts)
            end)
        end)
    else
        vim.lsp.start(config, start_opts)
    end
end

-- TODO: This module was a mistake. Get it out of here.
