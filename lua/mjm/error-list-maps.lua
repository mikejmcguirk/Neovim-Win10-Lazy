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

------------
--- GREP ---
------------

vim.keymap.set({ "n", "x" }, "<leader>qg", "<nop>")
vim.keymap.set({ "n", "x" }, "<leader>qG", "<nop>")
vim.keymap.set({ "n", "x" }, "<leader>q<C-g>", "<nop>")
vim.keymap.set({ "n", "x" }, "<leader>lg", "<nop>")
vim.keymap.set({ "n", "x" }, "<leader>lG", "<nop>")
vim.keymap.set({ "n", "x" }, "<leader>l<C-g>", "<nop>")

local eg = Qfr_Defer_Require("mjm.error-list-grep")

pnxmap("<Plug>(qf-rancher-grep-cwd-n)", "<Plug> Grep the CWD, new qflist", function()
    eg.grep_cwd_n()
end)

pnxmap("<Plug>(qf-rancher-grep-cwd-r)", "<Plug> Grep the CWD, replace qflist", function()
    eg.grep_cwd_r()
end)

pnxmap("<Plug>(qf-rancher-grep-cwd-a)", "<Plug> Grep the CWD, add to qflist", function()
    eg.grep_cwd_a()
end)

pnxmap("<Plug>(qf-rancher-lgrep-cwd-n)", "<Plug> Grep the CWD, new list", function()
    eg.lgrep_cwd_n()
end)

pnxmap("<Plug>(qf-rancher-lgrep-cwd-r)", "<Plug> Grep the CWD, replace list", function()
    eg.lgrep_cwd_r()
end)

pnxmap("<Plug>(qf-rancher-lgrep-cwd-a)", "<Plug> Grep the CWD, add to list", function()
    eg.lgrep_cwd_a()
end)

nxmap("<leader>qgd", "<Plug>(qf-rancher-grep-cwd-n)", "Grep the CWD, new qflist")
nxmap("<leader>qGd", "<Plug>(qf-rancher-grep-cwd-r)", "Grep the CWD, replace qflist")
nxmap("<leader>q<C-g>d", "<Plug>(qf-rancher-grep-cwd-a)", "Grep the CWD, add to qflist")
nxmap("<leader>lgd", "<Plug>(qf-rancher-lgrep-cwd-n)", "Grep the CWD, new loclist")
nxmap("<leader>lGd", "<Plug>(qf-rancher-lgrep-cwd-r)", "Grep the CWD, replace loclist")
nxmap("<leader>l<C-g>d", "<Plug>(qf-rancher-lgrep-cwd-a)", "Grep the CWD, add to loclist")

local pgCWDn_desc = "<Plug> Grep the CWD (case-sensitive), new qflist"
pnxmap("<Plug>(qf-rancher-grep-CWD-n)", pgCWDn_desc, function()
    eg.grep_CWD_n()
end)

local pgCWDr_desc = "<Plug> Grep the CWD (case-sensitive), replace qflist"
pnxmap("<Plug>(qf-rancher-grep-CWD-r)", pgCWDr_desc, function()
    eg.grep_CWD_r()
end)

local pgCWDa_desc = "<Plug> Grep the CWD (case-sensitive), add to qflist"
pnxmap("<Plug>(qf-rancher-grep-CWD-a)", pgCWDa_desc, function()
    eg.grep_CWD_a()
end)

local plgCWDn_desc = "<Plug> Grep the CWD (case-sensitive), new list"
pnxmap("<Plug>(qf-rancher-lgrep-CWD-n)", plgCWDn_desc, function()
    eg.lgrep_CWD_n()
end)

local plgCWDr_desc = "<Plug> Grep the CWD (case-sensitive), replace list"
pnxmap("<Plug>(qf-rancher-lgrep-CWD-r)", plgCWDr_desc, function()
    eg.lgrep_CWD_r()
end)

local plgCWDa_desc = "<Plug> Grep the CWD (case-sensitive), add to list"
pnxmap("<Plug>(qf-rancher-lgrep-CWD-a)", plgCWDa_desc, function()
    eg.lgrep_CWD_a()
end)

nxmap("<leader>qgD", "<Plug>(qf-rancher-grep-CWD-n)", "Grep the CWD (case-sensitive), new qflist")
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

local pgcwdXn_desc = "<Plug> Grep the cwdX (case-sensitive), new qflist"
pnxmap("<Plug>(qf-rancher-grep-cwdX-n)", pgcwdXn_desc, function()
    eg.grep_cwdX_n()
end)

local pgcwdXr_desc = "<Plug> Grep the cwdX (with regex), replace qflist"
pnxmap("<Plug>(qf-rancher-grep-cwdX-r)", pgcwdXr_desc, function()
    eg.grep_cwdX_r()
end)

local pgcwdXa_desc = "<Plug> Grep the cwdX (with regex), add to qflist"
pnxmap("<Plug>(qf-rancher-grep-cwdX-a)", pgcwdXa_desc, function()
    eg.grep_cwdX_a()
end)

local plgcwdXn_desc = "<Plug> Grep the cwdX (with regex), new list"
pnxmap("<Plug>(qf-rancher-lgrep-cwdX-n)", plgcwdXn_desc, function()
    eg.lgrep_cwdX_n()
end)

local plgcwdXr_desc = "<Plug> Grep the cwdX (with regex), replace list"
pnxmap("<Plug>(qf-rancher-lgrep-cwdX-r)", plgcwdXr_desc, function()
    eg.lgrep_cwdX_r()
end)

local plgcwdXa_desc = "<Plug> Grep the cwdX (with regex), add to list"
pnxmap("<Plug>(qf-rancher-lgrep-cwdX-a)", plgcwdXa_desc, function()
    eg.lgrep_cwdX_a()
end)

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
    vim.api.nvim_create_user_command("Qopen", function(arg)
        local count = arg.count > 0 and arg.count or nil
        eo.open_qflist({ always_resize = true, height = count })
    end, { count = 0 })

    vim.api.nvim_create_user_command("Lopen", function(arg)
        local count = arg.count > 0 and arg.count or nil
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
    vim.api.nvim_create_user_command("Qprev", function(arg)
        local count = arg.count > 0 and arg.count or 1
        en.q_prev(count)
    end, { count = 0 })

    vim.api.nvim_create_user_command("Qnext", function(arg)
        local count = arg.count > 0 and arg.count or 1
        en.q_next(count)
    end, { count = 0 })

    vim.api.nvim_create_user_command("Qq", function(arg)
        local count = arg.count > 0 and arg.count or 1
        en.q_q(count)
    end, { count = 0 })

    vim.api.nvim_create_user_command("Qpfile", function(arg)
        local count = arg.count > 0 and arg.count or 1
        en.q_pfile(count)
    end, { count = 0 })

    vim.api.nvim_create_user_command("Qnfile", function(arg)
        local count = arg.count > 0 and arg.count or 1
        en.q_nfile(count)
    end, { count = 0 })

    vim.api.nvim_create_user_command("Qjump", function(arg)
        local count = arg.count >= 0 and arg.count or 0
        en.q_jump(count)
    end, { count = 0 })

    vim.api.nvim_create_user_command("Lprev", function(arg)
        local count = arg.count > 0 and arg.count or 1
        en.l_prev(count)
    end, { count = 0 })

    vim.api.nvim_create_user_command("Lnext", function(arg)
        local count = arg.count > 0 and arg.count or 1
        en.l_next(count)
    end, { count = 0 })

    vim.api.nvim_create_user_command("Ll", function(arg)
        local count = arg.count > 0 and arg.count or 1
        en.l_l(count)
    end, { count = 0 })

    vim.api.nvim_create_user_command("Lpfile", function(arg)
        local count = arg.count > 0 and arg.count or 1
        en.l_pfile(count)
    end, { count = 0 })

    vim.api.nvim_create_user_command("Lnfile", function(arg)
        local count = arg.count > 0 and arg.count or 1
        en.l_nfile(count)
    end, { count = 0 })

    vim.api.nvim_create_user_command("Ljump", function(arg)
        local count = arg.count >= 0 and arg.count or 0
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
    vim.api.nvim_create_user_command("Qolder", function(arg)
        local count = arg.count > 0 and arg.count or 1
        es.q_older(count)
    end, { count = 0 })

    vim.api.nvim_create_user_command("Qnewer", function(arg)
        local count = arg.count > 0 and arg.count or 1
        es.q_newer(count)
    end, { count = 0 })

    vim.api.nvim_create_user_command("Qhistory", function(arg)
        local count = arg.count >= 0 and arg.count or 0
        es.q_history(count)
    end, { count = 0 })

    -- NOTE: Ideally, a count would override the "all" arg, in order to default to safer behavior,
    -- but the dict sent to the callback includes a count of 0 whether it was explicitly passed or
    -- not. Since a count of 0 can be explicitly passed, only overriding a count > 0 is convoluted
    vim.api.nvim_create_user_command("Qdelete", function(arg)
        if arg.args == "all" then
            es.q_del_all()
            return
        end

        local count = arg.count >= 0 and arg.count or 0
        es.q_del(count)
    end, { count = 0, nargs = "?" })

    vim.api.nvim_create_user_command("Lolder", function(arg)
        local count = arg.count > 0 and arg.count or 1
        es.l_older(count)
    end, { count = 0 })

    vim.api.nvim_create_user_command("Lnewer", function(arg)
        local count = arg.count > 0 and arg.count or 1
        es.l_newer(count)
    end, { count = 0 })

    vim.api.nvim_create_user_command("Lhistory", function(arg)
        local count = arg.count >= 0 and arg.count or 0
        es.l_history(count)
    end, { count = 0 })

    -- NOTE: Ideally, a count would override the "all" arg, in order to default to safer behavior,
    -- but the dict sent to the callback includes a count of 0 whether it was explicitly passed or
    -- not. Since a count of 0 can be explicitly passed, only overriding a count > 0 is convoluted
    vim.api.nvim_create_user_command("Ldelete", function(arg)
        if arg.args == "all" then
            es.l_del_all()
            return
        end

        local count = arg.count >= 0 and arg.count or 0
        es.l_del(count)
    end, { count = 0, nargs = "?" })
end
