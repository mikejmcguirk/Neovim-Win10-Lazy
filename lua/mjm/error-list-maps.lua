--- NOTE: In order for the defer require to work, all function calls must be inside of
--- anonymous functions. If you pass, for example, eo.closeqflist as a function reference, eo
--- needs to be evaluated at command creation, defeating the purpose of the defer require

local pmap = function(lhs, desc, cb)
    vim.api.nvim_set_keymap("n", lhs, "<nop>", { noremap = true, desc = desc, callback = cb })
end

local pnxmap = function(lhs, desc, cb)
    vim.api.nvim_set_keymap("n", lhs, "<nop>", { noremap = true, desc = desc, callback = cb })
    vim.api.nvim_set_keymap("x", lhs, "<nop>", { noremap = true, desc = desc, callback = cb })
end

local map = function(mode, lhs, rhs, desc)
    vim.api.nvim_set_keymap(mode, lhs, rhs, {
        noremap = true,
        desc = desc,
    })
end

local nxmap = function(lhs, rhs, desc)
    map("n", lhs, rhs, desc)
    map("x", lhs, rhs, desc)
end

-------------------
--- System Opts ---
-------------------

--- @type QfRancherSystemOpts
local sys_new = { async = true, timeout = 4000 }
--- @type QfRancherSystemOpts
local sys_replace = { async = true, replace = true, timeout = 4000 }
--- @type QfRancherSystemOpts
local sys_add = { async = true, add = true, timeout = 4000 }

--- @type QfRancherSystemOpts
local sys_lnew = { async = true, loclist = true, timeout = 4000 }
--- @type QfRancherSystemOpts
local sys_lreplace = { async = true, loclist = true, replace = true, timeout = 4000 }
--- @type QfRancherSystemOpts
local sys_ladd = { async = true, loclist = true, add = true, timeout = 4000 }

--- @type QfRancherSystemOpts
local sys_help_new = { async = true, type = "\1", timeout = 4000 }
--- @type QfRancherSystemOpts
local sys_help_replace = { async = true, type = "\1", replace = true, timeout = 4000 }
--- @type QfRancherSystemOpts
local sys_help_add = { async = true, type = "\1", add = true, timeout = 4000 }

--- @type QfRancherSystemOpts
local sys_help_lnew = { async = true, type = "\1", loclist = true, timeout = 4000 }
--- @type QfRancherSystemOpts
local sys_help_lreplace =
    { async = true, type = "\1", loclist = true, replace = true, timeout = 4000 }
--- @type QfRancherSystemOpts
local sys_help_ladd = { async = true, type = "\1", loclist = true, add = true, timeout = 4000 }

------------
--- GREP ---
------------

local grep_smart_case = { literal = true, smart_case = true }
local grep_case_sensitive = { literal = true }

nxmap("<leader>qg", "<nop>", "Avoid falling back to defaults")
nxmap("<leader>qG", "<nop>", "Avoid falling back to defaults")
nxmap("<leader>q<C-g>", "<nop>", "Avoid falling back to defaults")
nxmap("<leader>lg", "<nop>", "Avoid falling back to defaults")
nxmap("<leader>lG", "<nop>", "Avoid falling back to defaults")
nxmap("<leader>l<C-g>", "<nop>", "Avoid falling back to defaults")

local eg = Qfr_Defer_Require("mjm.error-list-grep")

pnxmap("<Plug>(qf-rancher-grep-cwd-n)", "<Plug> Grep the CWD, new qflist", function()
    eg.grep_cwd(grep_smart_case, sys_new)
end)

pnxmap("<Plug>(qf-rancher-grep-cwd-r)", "<Plug> Grep the CWD, replace qflist", function()
    eg.grep_cwd(grep_smart_case, sys_replace)
end)

pnxmap("<Plug>(qf-rancher-grep-cwd-a)", "<Plug> Grep the CWD, add to qflist", function()
    eg.grep_cwd(grep_smart_case, sys_add)
end)

pnxmap("<Plug>(qf-rancher-lgrep-cwd-n)", "<Plug> Grep the CWD, new loclist", function()
    eg.grep_cwd(grep_smart_case, sys_lnew)
end)

pnxmap("<Plug>(qf-rancher-lgrep-cwd-r)", "<Plug> Grep the CWD, replace loclist", function()
    eg.grep_cwd(grep_smart_case, sys_lreplace)
end)

pnxmap("<Plug>(qf-rancher-lgrep-cwd-a)", "<Plug> Grep the CWD, add to loclist", function()
    eg.grep_cwd(grep_smart_case, sys_ladd)
end)

local pgCWDn_desc = "<Plug> Grep the CWD (case-sensitive), new qflist"
pnxmap("<Plug>(qf-rancher-grep-CWD-n)", pgCWDn_desc, function()
    eg.grep_cwd(grep_case_sensitive, sys_new)
end)

local pgCWDr_desc = "<Plug> Grep the CWD (case-sensitive), replace qflist"
pnxmap("<Plug>(qf-rancher-grep-CWD-r)", pgCWDr_desc, function()
    eg.grep_cwd(grep_case_sensitive, sys_replace)
end)

local pgCWDa_desc = "<Plug> Grep the CWD (case-sensitive), add to qflist"
pnxmap("<Plug>(qf-rancher-grep-CWD-a)", pgCWDa_desc, function()
    eg.grep_cwd(grep_case_sensitive, sys_add)
end)

local plgCWDn_desc = "<Plug> Grep the CWD (case-sensitive), new loclist"
pnxmap("<Plug>(qf-rancher-lgrep-CWD-n)", plgCWDn_desc, function()
    eg.grep_cwd(grep_case_sensitive, sys_lnew)
end)

local plgCWDr_desc = "<Plug> Grep the CWD (case-sensitive), replace loclist"
pnxmap("<Plug>(qf-rancher-lgrep-CWD-r)", plgCWDr_desc, function()
    eg.grep_cwd(grep_case_sensitive, sys_lreplace)
end)

local plgCWDa_desc = "<Plug> Grep the CWD (case-sensitive), add to loclist"
pnxmap("<Plug>(qf-rancher-lgrep-CWD-a)", plgCWDa_desc, function()
    eg.grep_cwd(grep_case_sensitive, sys_ladd)
end)

local pgcwdXn_desc = "<Plug> Grep the cwdX (case-sensitive), new qflist"
pnxmap("<Plug>(qf-rancher-grep-cwdX-n)", pgcwdXn_desc, function()
    eg.grep_cwd({}, sys_new)
end)

local pgcwdXr_desc = "<Plug> Grep the cwdX (with regex), replace qflist"
pnxmap("<Plug>(qf-rancher-grep-cwdX-r)", pgcwdXr_desc, function()
    eg.grep_cwd({}, sys_replace)
end)

local pgcwdXa_desc = "<Plug> Grep the cwdX (with regex), add to qflist"
pnxmap("<Plug>(qf-rancher-grep-cwdX-a)", pgcwdXa_desc, function()
    eg.grep_cwd({}, sys_add)
end)

local plgcwdXn_desc = "<Plug> Grep the cwd (with regex), new loclist"
pnxmap("<Plug>(qf-rancher-lgrep-cwdX-n)", plgcwdXn_desc, function()
    eg.grep_cwd({}, sys_lnew)
end)

local plgcwdXr_desc = "<Plug> Grep the cwd (with regex), replace loclist"
pnxmap("<Plug>(qf-rancher-lgrep-cwdX-r)", plgcwdXr_desc, function()
    eg.grep_cwd({}, sys_lreplace)
end)

local plgcwdXa_desc = "<Plug> Grep the cwd (with regex), add to loclist"
pnxmap("<Plug>(qf-rancher-lgrep-cwdX-a)", plgcwdXa_desc, function()
    eg.grep_cwd({}, sys_ladd)
end)

pnxmap("<Plug>(qf-rancher-grep-help-n)", "<Plug> Grep the docs, new qflist", function()
    eg.grep_help(grep_smart_case, sys_help_new)
end)

pnxmap("<Plug>(qf-rancher-grep-help-r)", "<Plug> Grep the docs, replace qflist", function()
    eg.grep_help(grep_smart_case, sys_help_replace)
end)

pnxmap("<Plug>(qf-rancher-grep-help-a)", "<Plug> Grep the docs, add to qflist", function()
    eg.grep_help(grep_smart_case, sys_help_add)
end)

pnxmap("<Plug>(qf-rancher-lgrep-help-n)", "<Plug> Grep the docs, new loclist", function()
    eg.grep_help(grep_smart_case, sys_help_lnew)
end)

pnxmap("<Plug>(qf-rancher-lgrep-help-r)", "<Plug> Grep the docs, replace loclist", function()
    eg.grep_help(grep_smart_case, sys_help_lreplace)
end)

pnxmap("<Plug>(qf-rancher-lgrep-help-a)", "<Plug> Grep the docs, add to loclist", function()
    eg.grep_help(grep_smart_case, sys_help_ladd)
end)

local pgHELPn_desc = "<Plug> Grep the docs (case-sensitive), new qflist"
pnxmap("<Plug>(qf-rancher-grep-HELP-n)", pgHELPn_desc, function()
    eg.grep_help(grep_case_sensitive, sys_help_new)
end)

local pgHELPr_desc = "<Plug> Grep the docs (case-sensitive), replace qflist"
pnxmap("<Plug>(qf-rancher-grep-HELP-r)", pgHELPr_desc, function()
    eg.grep_help(grep_case_sensitive, sys_help_replace)
end)

local pgHELPa_desc = "<Plug> Grep the docs (case-sensitive), add to qflist"
pnxmap("<Plug>(qf-rancher-grep-HELP-a)", pgHELPa_desc, function()
    eg.grep_help(grep_case_sensitive, sys_help_add)
end)

local plgHELPn_desc = "<Plug> Grep the docs (case-sensitive), new loclist"
pnxmap("<Plug>(qf-rancher-lgrep-HELP-n)", plgHELPn_desc, function()
    eg.grep_help(grep_case_sensitive, sys_help_lnew)
end)

local plgHELPr_desc = "<Plug> Grep the docs (case-sensitive), replace loclist"
pnxmap("<Plug>(qf-rancher-lgrep-HELP-r)", plgHELPr_desc, function()
    eg.grep_help(grep_case_sensitive, sys_help_lreplace)
end)

local plgHELPa_desc = "<Plug> Grep the docs (case-sensitive), add to loclist"
pnxmap("<Plug>(qf-rancher-lgrep-HELP-a)", plgHELPa_desc, function()
    eg.grep_help(grep_case_sensitive, sys_help_ladd)
end)

local pghelpXn_desc = "<Plug> Grep the docs (with regen), new qflist"
pnxmap("<Plug>(qf-rancher-grep-helpX-n)", pghelpXn_desc, function()
    eg.grep_help({}, sys_help_new)
end)

local pghelpXr_desc = "<Plug> Grep the docs (with regex), replace qflist"
pnxmap("<Plug>(qf-rancher-grep-helpX-r)", pghelpXr_desc, function()
    eg.grep_help({}, sys_help_replace)
end)

local pghelpXa_desc = "<Plug> Grep the docs (with regex), add to qflist"
pnxmap("<Plug>(qf-rancher-grep-helpX-a)", pghelpXa_desc, function()
    eg.grep_help({}, sys_help_add)
end)

local plghelpXn_desc = "<Plug> Grep the docs (with regex), new loclist"
pnxmap("<Plug>(qf-rancher-lgrep-helpX-n)", plghelpXn_desc, function()
    eg.grep_help({}, sys_help_lnew)
end)

local plghelpXr_desc = "<Plug> Grep the docs (with regex), replace loclist"
pnxmap("<Plug>(qf-rancher-lgrep-helpX-r)", plghelpXr_desc, function()
    eg.grep_help({}, sys_help_lreplace)
end)

local plghelpXa_desc = "<Plug> Grep the docs (with regex), add to loclist"
pnxmap("<Plug>(qf-rancher-lgrep-helpX-a)", plghelpXa_desc, function()
    eg.grep_help(grep_smart_case, sys_help_ladd)
end)

pnxmap("<Plug>(qf-rancher-grep-bufs-n)", "<Plug> Grep open bufs, new qflist", function()
    eg.grep_bufs(grep_smart_case, sys_new)
end)

pnxmap("<Plug>(qf-rancher-grep-bufs-r)", "<Plug> Grep open bufs, replace qflist", function()
    eg.grep_bufs(grep_smart_case, sys_replace)
end)

pnxmap("<Plug>(qf-rancher-grep-bufs-a)", "<Plug> Grep open bufs, add to qflist", function()
    eg.grep_bufs(grep_smart_case, sys_add)
end)

local pgBUFSn_desc = "<Plug> Grep open bufs (case-sensitive), new qflist"
pnxmap("<Plug>(qf-rancher-grep-BUFS-n)", pgBUFSn_desc, function()
    eg.grep_bufs(grep_case_sensitive, sys_new)
end)

local pgBUFSr_desc = "<Plug> Grep open bufs (case-sensitive), replace qflist"
pnxmap("<Plug>(qf-rancher-grep-BUFS-r)", pgBUFSr_desc, function()
    eg.grep_bufs(grep_case_sensitive, sys_replace)
end)

local pgBUFSa_desc = "<Plug> Grep open bufs (case-sensitive), add to qflist"
pnxmap("<Plug>(qf-rancher-grep-BUFS-a)", pgBUFSa_desc, function()
    eg.grep_bufs(grep_case_sensitive, sys_add)
end)

local pgbufsXn_desc = "<Plug> Grep open bufs (case-sensitive), new qflist"
pnxmap("<Plug>(qf-rancher-grep-bufsX-n)", pgbufsXn_desc, function()
    eg.grep_bufs({}, sys_new)
end)

local pgbufsXr_desc = "<Plug> Grep open bufs (with regex), replace qflist"
pnxmap("<Plug>(qf-rancher-grep-bufsX-r)", pgbufsXr_desc, function()
    eg.grep_bufs({}, sys_replace)
end)

local pgbufsXa_desc = "<Plug> Grep open bufs (with regex), add to qflist"
pnxmap("<Plug>(qf-rancher-grep-bufsX-a)", pgbufsXa_desc, function()
    eg.grep_bufs({}, sys_add)
end)

pnxmap("<Plug>(qf-rancher-grep-cbuf-n)", "<Plug> Grep cur buf, new loclist", function()
    eg.grep_cbuf(grep_smart_case, sys_lnew)
end)

pnxmap("<Plug>(qf-rancher-grep-cbuf-r)", "<Plug> Grep cur buf, replace loclist", function()
    eg.grep_cbuf(grep_smart_case, sys_lreplace)
end)

pnxmap("<Plug>(qf-rancher-grep-cbuf-a)", "<Plug> Grep cur buf, add to loclist", function()
    eg.grep_cbuf(grep_smart_case, sys_ladd)
end)

local pgCBUFn_desc = "<Plug> Grep cur buf (case-sensitive), new loclist"
pnxmap("<Plug>(qf-rancher-grep-CBUF-n)", pgCBUFn_desc, function()
    eg.grep_cbuf(grep_case_sensitive, sys_lnew)
end)

local pgCBUFr_desc = "<Plug> Grep cur buf (case-sensitive), replace loclist"
pnxmap("<Plug>(qf-rancher-grep-CBUF-r)", pgCBUFr_desc, function()
    eg.grep_cbuf(grep_case_sensitive, sys_lreplace)
end)

local pgCBUFa_desc = "<Plug> Grep cur buf (case-sensitive), add to loclist"
pnxmap("<Plug>(qf-rancher-grep-CBUF-a)", pgCBUFa_desc, function()
    eg.grep_cbuf(grep_case_sensitive, sys_ladd)
end)

local pgcbufXn_desc = "<Plug> Grep cur buf (case-sensitive), new loclist"
pnxmap("<Plug>(qf-rancher-grep-cbufX-n)", pgcbufXn_desc, function()
    eg.grep_cbuf({}, sys_lnew)
end)

local pgcbufXr_desc = "<Plug> Grep cur buf (with regex), replace loclist"
pnxmap("<Plug>(qf-rancher-grep-cbufX-r)", pgcbufXr_desc, function()
    eg.grep_cbuf({}, sys_lreplace)
end)

local pgcbufXa_desc = "<Plug> Grep cur buf (with regex), add to loclist"
pnxmap("<Plug>(qf-rancher-grep-cbufX-a)", pgcbufXa_desc, function()
    eg.grep_cbuf({}, sys_ladd)
end)

if vim.g.qfrancher_setdefaultmaps then
    nxmap("<leader>qgd", "<Plug>(qf-rancher-grep-cwd-n)", "Grep the CWD, new qflist")
    nxmap("<leader>qGd", "<Plug>(qf-rancher-grep-cwd-r)", "Grep the CWD, replace qflist")
    nxmap("<leader>q<C-g>d", "<Plug>(qf-rancher-grep-cwd-a)", "Grep the CWD, add to qflist")
    nxmap("<leader>lgd", "<Plug>(qf-rancher-lgrep-cwd-n)", "Grep the CWD, new loclist")
    nxmap("<leader>lGd", "<Plug>(qf-rancher-lgrep-cwd-r)", "Grep the CWD, replace loclist")
    nxmap("<leader>l<C-g>d", "<Plug>(qf-rancher-lgrep-cwd-a)", "Grep the CWD, add to loclist")

    local gCWDn_desc = "Grep the CWD (case-sensitive), new qflist"
    nxmap("<leader>qgD", "<Plug>(qf-rancher-grep-CWD-n)", gCWDn_desc)
    local gCWDr_desc = "Grep the CWD (case-sensitive), replace qflist"
    nxmap("<leader>qGD", "<Plug>(qf-rancher-grep-CWD-r)", gCWDr_desc)
    local gCWDa_desc = "Grep the CWD (case-sensitive), add to qflist"
    nxmap("<leader>q<C-g>D", "<Plug>(qf-rancher-grep-CWD-a)", gCWDa_desc)
    local lgCWDn_desc = "Grep the CWD (case-sensitive), new loclist"
    nxmap("<leader>lgD", "<Plug>(qf-rancher-lgrep-CWD-n)", lgCWDn_desc)
    local lgCWDr_desc = "Grep the CWD (case-sensitive), replace loclist"
    nxmap("<leader>lGD", "<Plug>(qf-rancher-lgrep-CWD-r)", lgCWDr_desc)
    local lgCWDa_desc = "Grep the CWD (case-sensitive), add to loclist"
    nxmap("<leader>l<C-g>D", "<Plug>(qf-rancher-lgrep-CWD-a)", lgCWDa_desc)

    local gcwdXn_desc = "Grep the cwdX (with regex), new qflist"
    nxmap("<leader>qg<C-d>", "<Plug>(qf-rancher-grep-cwdX-n)", gcwdXn_desc)
    local gcwdXr_desc = "Grep the cwdX (with regex), replace qflist"
    nxmap("<leader>qG<C-d>", "<Plug>(qf-rancher-grep-cwdX-r)", gcwdXr_desc)
    local gcwdXa_desc = "Grep the cwdX (with regex), add to qflist"
    nxmap("<leader>q<C-g><C-d>", "<Plug>(qf-rancher-grep-cwdX-a)", gcwdXa_desc)
    local lgcwdXn_desc = "Grep the cwdX (with regex), new loclist"
    nxmap("<leader>lg<C-d>", "<Plug>(qf-rancher-lgrep-cwdX-n)", lgcwdXn_desc)
    local lgcwdXr_desc = "Grep the cwdX (with regex), replace loclist"
    nxmap("<leader>lG<C-d>", "<Plug>(qf-rancher-lgrep-cwdX-r)", lgcwdXr_desc)
    local lgcwdXa_desc = "Grep the cwdX (with regex), add to loclist"
    nxmap("<leader>l<C-g><C-d>", "<Plug>(qf-rancher-lgrep-cwdX-a)", lgcwdXa_desc)

    nxmap("<leader>qgh", "<Plug>(qf-rancher-grep-help-n)", "Grep the docs, new qflist")
    nxmap("<leader>qGh", "<Plug>(qf-rancher-grep-help-r)", "Grep the docs, replace qflist")
    nxmap("<leader>q<C-g>h", "<Plug>(qf-rancher-grep-help-a)", "Grep the docs, add to qflist")
    nxmap("<leader>lgh", "<Plug>(qf-rancher-lgrep-help-n)", "Grep the docs, new loclist")
    nxmap("<leader>lGh", "<Plug>(qf-rancher-lgrep-help-r)", "Grep the docs, replace loclist")
    nxmap("<leader>l<C-g>h", "<Plug>(qf-rancher-lgrep-help-a)", "Grep the docs, add to loclist")

    local gHELPn_desc = "Grep the docs (case-sensitive), new qflist"
    nxmap("<leader>qgH", "<Plug>(qf-rancher-grep-HELP-n)", gHELPn_desc)
    local gHELPr_desc = "Grep the docs (case-sensitive), replace qflist"
    nxmap("<leader>qGH", "<Plug>(qf-rancher-grep-HELP-r)", gHELPr_desc)
    local gHELPa_desc = "Grep the docs (case-sensitive), add to qflist"
    nxmap("<leader>q<C-g>H", "<Plug>(qf-rancher-grep-HELP-a)", gHELPa_desc)
    local lgHELPn_desc = "Grep the docs (case-sensitive), new loclist"
    nxmap("<leader>lgH", "<Plug>(qf-rancher-lgrep-HELP-n)", lgHELPn_desc)
    local lgHELPr_desc = "Grep the docs (case-sensitive), replace loclist"
    nxmap("<leader>lGH", "<Plug>(qf-rancher-lgrep-HELP-r)", lgHELPr_desc)
    local lgHELPa_desc = "Grep the docs (case-sensitive), add to loclist"
    nxmap("<leader>l<C-g>H", "<Plug>(qf-rancher-lgrep-HELP-a)", lgHELPa_desc)

    local ghelpXn_desc = "Grep the docs (with regex), new qflist"
    nxmap("<leader>qg<C-h>", "<Plug>(qf-rancher-grep-helpX-n)", ghelpXn_desc)
    local ghelpXr_desc = "Grep the docs (with regex), replace qflist"
    nxmap("<leader>qG<C-h>", "<Plug>(qf-rancher-grep-helpX-r)", ghelpXr_desc)
    local ghelpXa_desc = "Grep the docs (with regex), add to qflist"
    nxmap("<leader>q<C-g><C-h>", "<Plug>(qf-rancher-grep-helpX-a)", ghelpXa_desc)
    local lghelpXn_desc = "Grep the docs (with regex), new loclist"
    nxmap("<leader>lg<C-h>", "<Plug>(qf-rancher-lgrep-helpX-n)", lghelpXn_desc)
    local lghelpXr_desc = "Grep the docs (with regex), replace loclist"
    nxmap("<leader>lG<C-h>", "<Plug>(qf-rancher-lgrep-helpX-r)", lghelpXr_desc)
    local lghelpXa_desc = "Grep the docs (with regex), add to loclist"
    nxmap("<leader>l<C-g><C-h>", "<Plug>(qf-rancher-lgrep-helpX-a)", lghelpXa_desc)

    vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile" }, {
        group = vim.api.nvim_create_augroup("qfrancher-buf-grep-maps", { clear = true }),
        once = true,
        callback = function()
            nxmap("<leader>qgu", "<Plug>(qf-rancher-grep-bufs-n)", "Grep open bufs, new qflist")
            local gbufsr_desc = "Grep open bufs, replace qflist"
            nxmap("<leader>qGu", "<Plug>(qf-rancher-grep-bufs-r)", gbufsr_desc)
            local gbufsa_desc = "Grep open bufs, add to qflist"
            nxmap("<leader>q<C-g>u", "<Plug>(qf-rancher-grep-bufs-a)", gbufsa_desc)

            local gBUFSn_desc = "Grep open bufs (case-sensitive), new qflist"
            nxmap("<leader>qgU", "<Plug>(qf-rancher-grep-BUFS-n)", gBUFSn_desc)
            local gBUFSr_desc = "Grep open bufs (case-sensitive), replace qflist"
            nxmap("<leader>qGU", "<Plug>(qf-rancher-grep-BUFS-r)", gBUFSr_desc)
            local gBUFSa_desc = "Grep open bufs (case-sensitive), add to qflist"
            nxmap("<leader>q<C-g>U", "<Plug>(qf-rancher-grep-BUFS-a)", gBUFSa_desc)

            local gbufsXn_desc = "Grep open bufs (with regex), new qflist"
            nxmap("<leader>qg<C-u>", "<Plug>(qf-rancher-grep-bufsX-n)", gbufsXn_desc)
            local gbufsXr_desc = "Grep open bufs (with regex), replace qflist"
            nxmap("<leader>qG<C-u>", "<Plug>(qf-rancher-grep-bufsX-r)", gbufsXr_desc)
            local gbufsXa_desc = "Grep open bufs (with regex), add to qflist"
            nxmap("<leader>q<C-g><C-u>", "<Plug>(qf-rancher-grep-bufsX-a)", gbufsXa_desc)

            nxmap("<leader>lgu", "<Plug>(qf-rancher-grep-cbuf-n)", "Grep cur buf, new loclist")
            nxmap("<leader>lGu", "<Plug>(qf-rancher-grep-cbuf-r)", "Grep cur buf, replace loclist")
            local gcbufa_desc = "Grep cur buf, add to loclist"
            nxmap("<leader>l<C-g>u", "<Plug>(qf-rancher-grep-cbuf-a)", gcbufa_desc)

            local gCBUFn_desc = "Grep cur buf (case-sensitive), new loclist"
            nxmap("<leader>lgD", "<Plug>(qf-rancher-grep-CBUF-n)", gCBUFn_desc)
            local gCBUFr_desc = "Grep cur buf (case-sensitive), replace loclist"
            nxmap("<leader>lGU", "<Plug>(qf-rancher-grep-CBUF-r)", gCBUFr_desc)
            local gCBUFa_desc = "Grep cur buf (case-sensitive), add to loclist"
            nxmap("<leader>l<C-g>U", "<Plug>(qf-rancher-grep-CBUF-a)", gCBUFa_desc)

            local gcbufXn_desc = "Grep cur buf (with regex), new loclist"
            nxmap("<leader>lg<C-u>", "<Plug>(qf-rancher-grep-cbufX-n)", gcbufXn_desc)
            local gcbufXr_desc = "Grep cur buf (with regex), replace loclist"
            nxmap("<leader>lG<C-u>", "<Plug>(qf-rancher-grep-cbufX-r)", gcbufXr_desc)
            local gcbufXa_desc = "Grep cur buf (with regex), add to loclist"
            nxmap("<leader>l<C-g><C-u>", "<Plug>(qf-rancher-grep-cbufX-a)", gcbufXa_desc)
        end,
    })
end

local function find_matches(cargs, matches)
    cargs.fargs = cargs.fargs or {}
    for _, arg in ipairs(cargs.fargs) do
        if matches[arg] then
            return matches[arg]
        end
    end

    return matches.default
end

if vim.g.qfrancher_setdefaultcmds then
    vim.api.nvim_create_user_command("Qgrep", function(cargs)
        cargs = cargs or {}

        local types = { help = "help", buf = "buf", cwd = "cwd", default = "cwd" }
        local type = find_matches(cargs, types)

        local grep_options = {
            casesensitive = grep_case_sensitive,
            regex = {},
            smartcase = grep_smart_case,
            default = grep_smart_case,
        }

        local grep_opts = find_matches(cargs, grep_options)
        for _, arg in ipairs(cargs.fargs) do
            if string.sub(arg, 1, 1) == "/" then
                local pattern = string.sub(arg, 2)
                grep_opts = vim.tbl_deep_extend("force", grep_opts, { pattern = pattern })
                break
            end
        end

        local sys_opts = (function()
            for _, arg in ipairs(cargs.fargs) do
                if arg == "add" then
                    return type == "help" and sys_help_add or sys_add
                elseif arg == "replace" then
                    return type == "help" and sys_help_replace or sys_replace
                elseif arg == "new" then
                    return type == "help" and sys_help_new or sys_new
                end

                return type == "help" and sys_help_new or sys_new
            end
        end)()

        if type == "help" then
            eg.grep_help(grep_opts, sys_opts)
        elseif type == "buf" then
            eg.grep_bufs(grep_opts, sys_opts)
        else
            eg.grep_cwd(grep_opts, sys_opts)
        end
    end, { nargs = "*" })

    vim.api.nvim_create_user_command("Lgrep", function(cargs)
        cargs = cargs or {}

        local types = { help = "help", buf = "buf", cwd = "cwd", default = "cwd" }
        local type = find_matches(cargs, types)

        local grep_options = {
            casesensitive = grep_case_sensitive,
            regex = {},
            smartcase = grep_smart_case,
            default = grep_smart_case,
        }

        local grep_opts = find_matches(cargs.fargs, grep_options)
        for _, arg in ipairs(cargs.fargs) do
            if arg:match("^/") then
                local pattern = string.sub(arg, 2)
                grep_opts = vim.tbl_extend("force", grep_opts, { pattern = pattern })
                break
            end
        end

        local sys_opts = (function()
            for _, arg in ipairs(cargs.fargs) do
                if arg == "add" then
                    return type == "help" and sys_help_ladd or sys_ladd
                elseif arg == "replace" then
                    return type == "help" and sys_help_lreplace or sys_lreplace
                elseif arg == "new" then
                    return type == "help" and sys_help_lnew or sys_lnew
                end

                return type == "help" and sys_help_lnew or sys_lnew
            end
        end)()

        if type == "help" then
            eg.grep_help(grep_opts, sys_opts)
        elseif type == "buf" then
            eg.grep_bufs(grep_opts, sys_opts)
        else
            eg.grep_cwd(grep_opts, sys_opts)
        end
    end, { nargs = "*" })
end

-------------------------
--- OPEN_CLOSE_TOGGLE ---
-------------------------

local eo = Qfr_Defer_Require("mjm.error-list-open")

pmap("<Plug>(qf-rancher-open-qf-list)", "<Plug> Open the quickfix list", function()
    local height = vim.v.count > 0 and vim.v.count or nil
    eo.open_qflist({ always_resize = true, height = height })
end)

pmap("<Plug>(qf-rancher-close-qf-list)", "<Plug> Close the quickfix list", function()
    eo.close_qflist()
end)

pmap("<Plug>(qf-rancher-toggle-qf-list)", "<Plug> Toggle the quickfix list", function()
    if not eo.open_qflist() then
        eo.close_qflist()
    end
end)

pmap("<Plug>(qf-rancher-open-loclist)", "<Plug> Open the location list", function()
    local height = vim.v.count > 0 and vim.v.count or nil
    eo.open_loclist({ always_resize = true, height = height })
end)

pmap("<Plug>(qf-rancher-close-loclist)", "<Plug> Close the location list", function()
    eo.close_loclist()
end)

pmap("<Plug>(qf-rancher-toggle-loclist)", "<Plug> Toggle the location list", function()
    if not eo.open_loclist({ suppress_errors = true }) then
        eo.close_loclist()
    end
end)

if vim.g.qfrancher_setdefaultmaps then
    map("n", "<leader>q", "<nop>", "Prevent fallback to other mappings")
    map("n", "<leader>l", "<nop>", "Prevent fallback to other mappings")

    map("n", "<leader>qp", "<Plug>(qf-rancher-open-qf-list)", "Open the quickfix list")
    map("n", "<leader>qo", "<Plug>(qf-rancher-close-qf-list)", "Close the quickfix list")
    map("n", "<leader>qq", "<Plug>(qf-rancher-toggle-qf-list)", "Toggle the quickfix list")

    map("n", "<leader>lp", "<Plug>(qf-rancher-open-loclist)", "Open the location list")
    map("n", "<leader>lo", "<Plug>(qf-rancher-close-loclist)", "Close the location list")
    map("n", "<leader>ll", "<Plug>(qf-rancher-toggle-loclist)", "Toggle the location list")
end

if vim.g.qfrancher_setdefaultcmds then
    vim.api.nvim_create_user_command("Qopen", function(cargs)
        cargs = cargs or {}
        local count = cargs.count > 0 and cargs.count or nil
        eo.open_qflist({ always_resize = true, height = count })
    end, { count = 0 })

    vim.api.nvim_create_user_command("Lopen", function(cargs)
        cargs = cargs or {}
        local count = cargs.count > 0 and cargs.count or nil
        eo.open_loclist({ always_resize = true, height = count })
    end, { count = 0 })

    vim.api.nvim_create_user_command("Qclose", function()
        eo.close_qflist()
    end, {})

    vim.api.nvim_create_user_command("Lclose", function()
        eo.close_loclist()
    end, {})
end

------------------
--- NAV_ACTION ---
------------------

local en = Qfr_Defer_Require("mjm.error-list-nav-action")

pmap("<Plug>(qf-rancher-qf-prev)", "<Plug> Go to a previous qf entry", function()
    en.q_prev(vim.v.count1)
end)

pmap("<Plug>(qf-rancher-qf-next)", "<Plug> Go to a later qf entry", function()
    en.q_next(vim.v.count1)
end)

pmap("<Plug>(qf-rancher-qf-pfile)", "<Plug> Go to the previous qf file", function()
    en.q_pfile(vim.v.count1)
end)

pmap("<Plug>(qf-rancher-qf-nfile)", "<Plug> Go to the next qf file", function()
    en.q_nfile(vim.v.count1)
end)

pmap("<Plug>(qf-rancher-qf-jump)", "<Plug> Jump to the qflist", function()
    en.q_jump(vim.v.count)
end)

pmap("<Plug>(qf-rancher-ll-prev)", "<Plug> Go to a previous loclist entry", function()
    en.l_prev(vim.v.count1)
end)

pmap("<Plug>(qf-rancher-ll-next)", "<Plug> Go to a previous loclist entry", function()
    en.l_next(vim.v.count1)
end)

pmap("<Plug>(qf-rancher-ll-pfile)", "<Plug> Go to the previous loclist file", function()
    en.l_pfile(vim.v.count1)
end)

pmap("<Plug>(qf-rancher-ll-nfile)", "<Plug> Go to the next loclist file", function()
    en.l_nfile(vim.v.count1)
end)

pmap("<Plug>(qf-rancher-ll-jump)", "<Plug> Jump to the loclist", function()
    en.l_jump(vim.v.count)
end)

if vim.g.qfrancher_setdefaultmaps then
    map("n", "[q", "<Plug>(qf-rancher-qf-prev)", "Go to a previous qf entry")
    map("n", "]q", "<Plug>(qf-rancher-qf-next)", "Go to a later qf entry")
    map("n", "[<C-q>", "<Plug>(qf-rancher-qf-pfile)", "Go to the previous qf file")
    map("n", "]<C-q>", "<Plug>(qf-rancher-qf-nfile)", "Go to the next qf file")
    map("n", "<leader>q<C-q>", "<Plug>(qf-rancher-qf-jump)", "Jump to the qflist")

    map("n", "[l", "<Plug>(qf-rancher-ll-prev)", "Go to a previous loclist entry")
    map("n", "]l", "<Plug>(qf-rancher-ll-next)", "Go to a previous loclist entry")
    map("n", "[<C-l>", "<Plug>(qf-rancher-ll-pfile)", "Go to the previous loclist file")
    map("n", "]<C-l>", "<Plug>(qf-rancher-ll-nfile)", "Go to the next loclist file")
    map("n", "<leader>l<C-l>", "<Plug>(qf-rancher-ll-jump)", "Jump to the loclist")
end

if vim.g.qfrancher_setdefaultcmds then
    vim.api.nvim_create_user_command("Qprev", function(cargs)
        cargs = cargs or {}
        local count = cargs.count > 0 and cargs.count or 1
        en.q_prev(count)
    end, { count = 0 })

    vim.api.nvim_create_user_command("Qnext", function(cargs)
        cargs = cargs or {}
        local count = cargs.count > 0 and cargs.count or 1
        en.q_next(count)
    end, { count = 0 })

    vim.api.nvim_create_user_command("Qq", function(cargs)
        cargs = cargs or {}
        local count = cargs.count > 0 and cargs.count or 1
        en.q_q(count)
    end, { count = 0 })

    vim.api.nvim_create_user_command("Qpfile", function(cargs)
        cargs = cargs or {}
        local count = cargs.count > 0 and cargs.count or 1
        en.q_pfile(count)
    end, { count = 0 })

    vim.api.nvim_create_user_command("Qnfile", function(cargs)
        cargs = cargs or {}
        local count = cargs.count > 0 and cargs.count or 1
        en.q_nfile(count)
    end, { count = 0 })

    vim.api.nvim_create_user_command("Qjump", function(cargs)
        cargs = cargs or {}
        local count = cargs.count >= 0 and cargs.count or 0
        en.q_jump(count)
    end, { count = 0 })

    vim.api.nvim_create_user_command("Lprev", function(cargs)
        cargs = cargs or {}
        local count = cargs.count > 0 and cargs.count or 1
        en.l_prev(count)
    end, { count = 0 })

    vim.api.nvim_create_user_command("Lnext", function(cargs)
        cargs = cargs or {}
        local count = cargs.count > 0 and cargs.count or 1
        en.l_next(count)
    end, { count = 0 })

    vim.api.nvim_create_user_command("Ll", function(cargs)
        cargs = cargs or {}
        local count = cargs.count > 0 and cargs.count or 1
        en.l_l(count)
    end, { count = 0 })

    vim.api.nvim_create_user_command("Lpfile", function(cargs)
        cargs = cargs or {}
        local count = cargs.count > 0 and cargs.count or 1
        en.l_pfile(count)
    end, { count = 0 })

    vim.api.nvim_create_user_command("Lnfile", function(cargs)
        cargs = cargs or {}
        local count = cargs.count > 0 and cargs.count or 1
        en.l_nfile(count)
    end, { count = 0 })

    vim.api.nvim_create_user_command("Ljump", function(cargs)
        cargs = cargs or {}
        local count = cargs.count >= 0 and cargs.count or 0
        en.l_jump(count)
    end, { count = 0 })
end

-------------
--- STACK ---
-------------

local es = Qfr_Defer_Require("mjm.error-list-stack")

pmap("<Plug>(qf-rancher-qf-older)", "<Plug> Go to an older qflist", function()
    es.q_older(vim.v.count1)
end)

pmap("<Plug>(qf-rancher-qf-newer)", "<Plug> Go to a newer qflist", function()
    es.q_newer(vim.v.count1)
end)

pmap("<Plug>(qf-rancher-qf-history)", "<Plug> View or jump within the quickfix history", function()
    es.q_history(vim.v.count)
end)

pmap("<Plug>(qf-rancher-qf-del)", "<Plug> Delete a list from the quickfix stack", function()
    es.q_del(vim.v.count)
end)

pmap("<Plug>(qf-rancher-qf-del-all)", "<Plug> Delete all items from the quickfix stack", function()
    es.q_del_all()
end)

pmap("<Plug>(qf-rancher-ll-older)", "<Plug> Go to an older location list", function()
    es.l_older(vim.v.count1)
end)

pmap("<Plug>(qf-rancher-ll-newer)", "<Plug> Go to a newer location list", function()
    es.l_newer(vim.v.count1)
end)

pmap("<Plug>(qf-rancher-ll-history)", "<Plug> View or jump within the loclist history", function()
    es.l_history(vim.v.count)
end)

pmap("<Plug>(qf-rancher-ll-del)", "<Plug> Delete a list from the loclist stack", function()
    es.l_del(vim.v.count)
end)

pmap("<Plug>(qf-rancher-ll-del-all)", "<Plug> Delete all items from the loclist stack", function()
    es.l_del_all()
end)

if vim.g.qfrancher_setdefaultmaps then
    map("n", "<leader>q[", "<Plug>(qf-rancher-qf-older)", "Go to an older qflist")
    map("n", "<leader>q]", "<Plug>(qf-rancher-qf-newer)", "Go to a newer qflist")
    map("n", "<leader>qQ", "<Plug>(qf-rancher-qf-history)", "View/jump the quickfix history")
    map("n", "<leader>qe", "<Plug>(qf-rancher-qf-del)", "Delete a list from the quickfix stack")
    map("n", "<leader>qE", "<Plug>(qf-rancher-qf-del-all)", "Purge the quickfix stack")

    map("n", "<leader>l[", "<Plug>(qf-rancher-ll-older)", "Go to an older loclist")
    map("n", "<leader>l]", "<Plug>(qf-rancher-ll-newer)", "Go to a newer loclist")
    map("n", "<leader>lL", "<Plug>(qf-rancher-ll-history)", "View/jump the loclist history")
    map("n", "<leader>le", "<Plug>(qf-rancher-ll-del)", "Delete a list from the loclist stack")
    map("n", "<leader>lE", "<Plug>(qf-rancher-ll-del-all)", "Purge the loclist stack")
end

if vim.g.qfrancher_setdefaultcmds then
    vim.api.nvim_create_user_command("Qolder", function(cargs)
        cargs = cargs or {}

        local count = cargs.count > 0 and cargs.count or 1
        es.q_older(count)
    end, { count = 0 })

    vim.api.nvim_create_user_command("Qnewer", function(cargs)
        cargs = cargs or {}

        local count = cargs.count > 0 and cargs.count or 1
        es.q_newer(count)
    end, { count = 0 })

    vim.api.nvim_create_user_command("Qhistory", function(cargs)
        cargs = cargs or {}

        local count = cargs.count >= 0 and cargs.count or 0
        es.q_history(count)
    end, { count = 0 })

    -- NOTE: Ideally, a count would override the "all" arg, in order to default to safer behavior,
    -- but the dict sent to the callback includes a count of 0 whether it was explicitly passed or
    -- not. Since a count of 0 can be explicitly passed, only overriding a count > 0 is convoluted
    vim.api.nvim_create_user_command("Qdelete", function(cargs)
        cargs = cargs or {}

        if cargs.args == "all" then
            es.q_del_all()
            return
        end

        local count = cargs.count >= 0 and cargs.count or 0
        es.q_del(count)
    end, { count = 0, nargs = "?" })

    vim.api.nvim_create_user_command("Lolder", function(cargs)
        cargs = cargs or {}

        local count = cargs.count > 0 and cargs.count or 1
        es.l_older(count)
    end, { count = 0 })

    vim.api.nvim_create_user_command("Lnewer", function(cargs)
        cargs = cargs or {}

        local count = cargs.count > 0 and cargs.count or 1
        es.l_newer(count)
    end, { count = 0 })

    vim.api.nvim_create_user_command("Lhistory", function(cargs)
        cargs = cargs or {}

        local count = cargs.count >= 0 and cargs.count or 0
        es.l_history(count)
    end, { count = 0 })

    -- NOTE: Ideally, a count would override the "all" arg, in order to default to safer behavior,
    -- but the dict sent to the callback includes a count of 0 whether it was explicitly passed or
    -- not. Since a count of 0 can be explicitly passed, only overriding a count > 0 is convoluted
    vim.api.nvim_create_user_command("Ldelete", function(cargs)
        cargs = cargs or {}

        if cargs.args == "all" then
            es.l_del_all()
            return
        end

        local count = cargs.count >= 0 and cargs.count or 0
        es.l_del(count)
    end, { count = 0, nargs = "?" })
end
