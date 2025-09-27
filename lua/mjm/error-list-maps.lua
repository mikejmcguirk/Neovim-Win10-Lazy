--- NOTE: In order for the defer require to work, all function calls must be inside of
--- anonymous functions. If you pass, for example, eo.closeqflist as a function reference, eo
--- needs to be evaluated at command creation, defeating the purpose of the defer require

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

local ef = Qfr_Defer_Require("mjm.error-list-filter")
local eg = Qfr_Defer_Require("mjm.error-list-grep")
local en = Qfr_Defer_Require("mjm.error-list-nav-action")
local eo = Qfr_Defer_Require("mjm.error-list-open")
local es = Qfr_Defer_Require("mjm.error-list-stack")

local grep_smart_case = { literal = true, smart_case = true }
local grep_case_sensitive = { literal = true }

local rancher_keymaps = {
    {
        modes = { "n", "x" },
        plug = "<nop>",
        map = "<leader>q",
        desc = "Avoid falling back to defaults",
        callback = nil,
    },
    {
        modes = { "n", "x" },
        plug = "<nop>",
        map = "<leader>l",
        desc = "Avoid falling back to defaults",
        callback = nil,
    },

    --------------
    --- FILTER ---
    --------------

    {
        modes = { "n", "x" },
        plug = "<nop>",
        map = "<leader>qk",
        desc = "Avoid falling back to defaults",
        callback = nil,
    },
    {
        modes = { "n", "x" },
        plug = "<nop>",
        map = "<leader>qr",
        desc = "Avoid falling back to defaults",
        callback = nil,
    },
    {
        modes = { "n", "x" },
        plug = "<nop>",
        map = "<leader>lk",
        desc = "Avoid falling back to defaults",
        callback = nil,
    },
    {
        modes = { "n", "x" },
        plug = "<nop>",
        map = "<leader>lr",
        desc = "Avoid falling back to defaults",
        callback = nil,
    },
    {
        modes = { "n", "x" },
        plug = "<nop>",
        map = "<leader>qK",
        desc = "Avoid falling back to defaults",
        callback = nil,
    },
    {
        modes = { "n", "x" },
        plug = "<nop>",
        map = "<leader>qR",
        desc = "Avoid falling back to defaults",
        callback = nil,
    },
    {
        modes = { "n", "x" },
        plug = "<nop>",
        map = "<leader>lK",
        desc = "Avoid falling back to defaults",
        callback = nil,
    },
    {
        modes = { "n", "x" },
        plug = "<nop>",
        map = "<leader>lR",
        desc = "Avoid falling back to defaults",
        callback = nil,
    },
    {
        modes = { "n", "x" },
        plug = "<nop>",
        map = "<leader>q<c-k>",
        desc = "Avoid falling back to defaults",
        callback = nil,
    },
    {
        modes = { "n", "x" },
        plug = "<nop>",
        map = "<leader>q<c-r>",
        desc = "Avoid falling back to defaults",
        callback = nil,
    },
    {
        modes = { "n", "x" },
        plug = "<nop>",
        map = "<leader>l<c-k>",
        desc = "Avoid falling back to defaults",
        callback = nil,
    },
    {
        modes = { "n", "x" },
        plug = "<nop>",
        map = "<leader>l<c-r>",
        desc = "Avoid falling back to defaults",
        callback = nil,
    },
    {
        modes = { "n" },
        plug = "<Plug>(qf-rancher-qfilter-keep-cfilter-n)",
        map = "<leader>qkl",
        desc = "Filter Qflist to keep with Cfilter emulation. Create new list on count. "
            .. "Case insensitive/smartcase",
        callback = function()
            ef.cfilter(false, { insensitive = true, keep = true }, { action = "new" })
        end,
    },
    {
        modes = { "n" },
        plug = "<Plug>(qf-rancher-qfilter-keep-cfilter-r)",
        map = "<leader>qKl",
        desc = "Filter Qflist to keep with Cfilter emulation. Replace list with count. "
            .. "Case insensitive/smartcase",
        callback = function()
            ef.cfilter(false, { insensitive = true, keep = true }, { action = "replace" })
        end,
    },
    {
        modes = { "n" },
        plug = "<Plug>(qf-rancher-qfilter-keep-cfilter-a)",
        map = "<leader>q<C-k>l",
        desc = "Filter Qflist to keep with Cfilter emulation. Mege list with count. "
            .. "Case insensitive/smartcase",
        callback = function()
            ef.cfilter(false, { insensitive = true, keep = true }, { action = "merge" })
        end,
    },
    {
        modes = { "n" },
        plug = "<Plug>(qf-rancher-lfilter-keep-cfilter-n)",
        map = "<leader>lkl",
        desc = "Filter loclist to keep with Cfilter emulation. Create new list on count. "
            .. "Case insensitive/smartcase",
        callback = function()
            ef.cfilter(true, { insensitive = true, keep = true }, { action = "new" })
        end,
    },
    {
        modes = { "n" },
        plug = "<Plug>(qf-rancher-lfilter-keep-cfilter-r)",
        map = "<leader>qKl",
        desc = "Filter loclist to keep with Cfilter emulation. Replace list with count. "
            .. "Case insensitive/smartcase",
        callback = function()
            ef.cfilter(true, { insensitive = true, keep = true }, { action = "replace" })
        end,
    },
    {
        modes = { "n" },
        plug = "<Plug>(qf-rancher-lfilter-keep-cfilter-a)",
        map = "<leader>q<C-k>l",
        desc = "Filter loclist to keep with Cfilter emulation. Mege list with count. "
            .. "Case insensitive/smartcase",
        callback = function()
            ef.cfilter(true, { insensitive = true, keep = true }, { action = "merge" })
        end,
    },
    {
        modes = { "n" },
        plug = "<Plug>(qf-rancher-qfilter-remove-cfilter-n)",
        map = "<leader>qkr",
        desc = "Filter Qflist to remove with Cfilter emulation. Create new list on count. "
            .. "Case insensitive/smartcase",
        callback = function()
            ef.cfilter(false, { insensitive = true, keep = false }, { action = "new" })
        end,
    },
    {
        modes = { "n" },
        plug = "<Plug>(qf-rancher-qfilter-remove-cfilter-r)",
        map = "<leader>qKr",
        desc = "Filter Qflist to remove with Cfilter emulation. Replace list with count. "
            .. "Case insensitive/smartcase",
        callback = function()
            ef.cfilter(false, { insensitive = true, keep = false }, { action = "replace" })
        end,
    },
    {
        modes = { "n" },
        plug = "<Plug>(qf-rancher-qfilter-remove-cfilter-a)",
        map = "<leader>q<C-k>r",
        desc = "Filter Qflist to remove with Cfilter emulation. Mege list with count. "
            .. "Case insensitive/smartcase",
        callback = function()
            ef.cfilter(false, { insensitive = true, keep = false }, { action = "merge" })
        end,
    },
    {
        modes = { "n" },
        plug = "<Plug>(qf-rancher-lfilter-remove-cfilter-n)",
        map = "<leader>lkr",
        desc = "Filter loclist to remove with Cfilter emulation. Create new list on count. "
            .. "Case insensitive/smartcase",
        callback = function()
            ef.cfilter(true, { insensitive = true, keep = false }, { action = "new" })
        end,
    },
    {
        modes = { "n" },
        plug = "<Plug>(qf-rancher-lfilter-remove-cfilter-r)",
        map = "<leader>qKr",
        desc = "Filter loclist to remove with Cfilter emulation. Replace list with count. "
            .. "Case insensitive/smartcase",
        callback = function()
            ef.cfilter(true, { insensitive = true, keep = false }, { action = "replace" })
        end,
    },
    {
        modes = { "n" },
        plug = "<Plug>(qf-rancher-lfilter-remove-cfilter-a)",
        map = "<leader>q<C-k>r",
        desc = "Filter loclist to remove with Cfilter emulation. Mege list with count. "
            .. "Case insensitive/smartcase",
        callback = function()
            ef.cfilter(true, { insensitive = true, keep = false }, { action = "merge" })
        end,
    },

    ------------
    --- GREP ---
    ------------

    {
        modes = { "n", "x" },
        plug = "<nop>",
        map = "<leader>qg",
        desc = "Avoid falling back to defaults",
        callback = nil,
    },
    {
        modes = { "n", "x" },
        plug = "<nop>",
        map = "<leader>lg",
        desc = "Avoid falling back to defaults",
        callback = nil,
    },
    {
        modes = { "n", "x" },
        plug = "<nop>",
        map = "<leader>qG",
        desc = "Avoid falling back to defaults",
        callback = nil,
    },
    {
        modes = { "n", "x" },
        plug = "<nop>",
        map = "<leader>lG",
        desc = "Avoid falling back to defaults",
        callback = nil,
    },
    {
        modes = { "n", "x" },
        plug = "<nop>",
        map = "<leader>q<c-g>",
        desc = "Avoid falling back to defaults",
        callback = nil,
    },
    {
        modes = { "n", "x" },
        plug = "<nop>",
        map = "<leader>l<c-g>",
        desc = "Avoid falling back to defaults",
        callback = nil,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-grep-cwd-n)",
        map = "<leader>qgd",
        desc = "Grep the CWD, new qflist",
        callback = function()
            eg.grep_cwd(grep_smart_case, sys_new)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-grep-cwd-r)",
        map = "<leader>qGd",
        desc = "Grep the CWD, replace qflist",
        callback = function()
            eg.grep_cwd(grep_smart_case, sys_replace)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-grep-cwd-a)",
        map = "<leader>q<C-g>d",
        desc = "Grep the CWD, add to qflist",
        callback = function()
            eg.grep_cwd(grep_smart_case, sys_add)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-lgrep-cwd-n)",
        map = "<leader>lgd",
        desc = "Grep the CWD, new loclist",
        callback = function()
            eg.grep_cwd(grep_smart_case, sys_lnew)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-lgrep-cwd-r)",
        map = "<leader>lGd",
        desc = "Grep the CWD, replace loclist",
        callback = function()
            eg.grep_cwd(grep_smart_case, sys_lreplace)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-lgrep-cwd-a)",
        map = "<leader>l<C-g>d",
        desc = "Grep the CWD, add to loclist",
        callback = function()
            eg.grep_cwd(grep_smart_case, sys_ladd)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-grep-CWD-n)",
        map = "<leader>qgD",
        desc = "Grep the CWD (case-sensitive), new qflist",
        callback = function()
            eg.grep_cwd(grep_case_sensitive, sys_new)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-grep-CWD-r)",
        map = "<leader>qGD",
        desc = "Grep the CWD (case-sensitive), replace qflist",
        callback = function()
            eg.grep_cwd(grep_case_sensitive, sys_replace)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-grep-CWD-a)",
        map = "<leader>q<C-g>D",
        desc = "Grep the CWD (case-sensitive), add to qflist",
        callback = function()
            eg.grep_cwd(grep_case_sensitive, sys_add)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-lgrep-CWD-n)",
        map = "<leader>lgD",
        desc = "Grep the CWD (case-sensitive), new loclist",
        callback = function()
            eg.grep_cwd(grep_case_sensitive, sys_lnew)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-lgrep-CWD-r)",
        map = "<leader>lGD",
        desc = "Grep the CWD (case-sensitive), replace loclist",
        callback = function()
            eg.grep_cwd(grep_case_sensitive, sys_lreplace)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-lgrep-CWD-a)",
        map = "<leader>l<C-g>D",
        desc = "Grep the CWD (case-sensitive), add to loclist",
        callback = function()
            eg.grep_cwd(grep_case_sensitive, sys_ladd)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-grep-cwdX-n)",
        map = "<leader>qg<C-d>",
        desc = "Grep the cwdX (with regex), new qflist",
        callback = function()
            eg.grep_cwd({}, sys_new)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-grep-cwdX-r)",
        map = "<leader>qG<C-d>",
        desc = "Grep the cwdX (with regex), replace qflist",
        callback = function()
            eg.grep_cwd({}, sys_replace)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-grep-cwdX-a)",
        map = "<leader>q<C-g><C-d>",
        desc = "Grep the cwdX (with regex), add to qflist",
        callback = function()
            eg.grep_cwd({}, sys_add)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-lgrep-cwdX-n)",
        map = "<leader>lg<C-d>",
        desc = "Grep the cwdX (with regex), new loclist",
        callback = function()
            eg.grep_cwd({}, sys_lnew)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-lgrep-cwdX-r)",
        map = "<leader>lG<C-d>",
        desc = "Grep the cwdX (with regex), replace loclist",
        callback = function()
            eg.grep_cwd({}, sys_lreplace)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-lgrep-cwdX-a)",
        map = "<leader>l<C-g><C-d>",
        desc = "Grep the cwdX (with regex), add to loclist",
        callback = function()
            eg.grep_cwd({}, sys_ladd)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-grep-help-n)",
        map = "<leader>qgh",
        desc = "Grep the docs, new qflist",
        callback = function()
            eg.grep_help(grep_smart_case, sys_help_new)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-grep-help-r)",
        map = "<leader>qGh",
        desc = "Grep the docs, replace qflist",
        callback = function()
            eg.grep_help(grep_smart_case, sys_help_replace)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-grep-help-a)",
        map = "<leader>q<C-g>h",
        desc = "Grep the docs, add to qflist",
        callback = function()
            eg.grep_help(grep_smart_case, sys_help_add)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-lgrep-help-n)",
        map = "<leader>lgh",
        desc = "Grep the docs, new loclist",
        callback = function()
            eg.grep_help(grep_smart_case, sys_help_lnew)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-lgrep-help-r)",
        map = "<leader>lGh",
        desc = "Grep the docs, replace loclist",
        callback = function()
            eg.grep_help(grep_smart_case, sys_help_lreplace)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-lgrep-help-a)",
        map = "<leader>l<C-g>h",
        desc = "Grep the docs, add to loclist",
        callback = function()
            eg.grep_help(grep_smart_case, sys_help_ladd)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-grep-HELP-n)",
        map = "<leader>qgH",
        desc = "Grep the docs (case-sensitive), new qflist",
        callback = function()
            eg.grep_help(grep_case_sensitive, sys_help_new)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-grep-HELP-r)",
        map = "<leader>qGH",
        desc = "Grep the docs (case-sensitive), replace qflist",
        callback = function()
            eg.grep_help(grep_case_sensitive, sys_help_replace)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-grep-HELP-a)",
        map = "<leader>q<C-g>H",
        desc = "Grep the docs (case-sensitive), add to qflist",
        callback = function()
            eg.grep_help(grep_case_sensitive, sys_help_add)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-lgrep-HELP-n)",
        map = "<leader>lgH",
        desc = "Grep the docs (case-sensitive), new loclist",
        callback = function()
            eg.grep_help(grep_case_sensitive, sys_help_lnew)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-lgrep-HELP-r)",
        map = "<leader>lGH",
        desc = "Grep the docs (case-sensitive), replace loclist",
        callback = function()
            eg.grep_help(grep_case_sensitive, sys_help_lreplace)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-lgrep-HELP-a)",
        map = "<leader>l<C-g>H",
        desc = "Grep the docs (case-sensitive), add to loclist",
        callback = function()
            eg.grep_help(grep_case_sensitive, sys_help_ladd)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-grep-helpX-n)",
        map = "<leader>qg<C-h>",
        desc = "Grep the docs (with regex), new qflist",
        callback = function()
            eg.grep_help({}, sys_help_new)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-grep-helpX-r)",
        map = "<leader>qG<C-h>",
        desc = "Grep the docs (with regex), replace qflist",
        callback = function()
            eg.grep_help({}, sys_help_replace)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-grep-helpX-a)",
        map = "<leader>q<C-g><C-h>",
        desc = "Grep the docs (with regex), add to qflist",
        callback = function()
            eg.grep_help({}, sys_help_add)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-lgrep-helpX-n)",
        map = "<leader>lg<C-h>",
        desc = "Grep the docs (with regex), new loclist",
        callback = function()
            eg.grep_help({}, sys_help_lnew)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-lgrep-helpX-r)",
        map = "<leader>lG<C-h>",
        desc = "Grep the docs (with regex), replace loclist",
        callback = function()
            eg.grep_help({}, sys_help_lreplace)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-lgrep-helpX-a)",
        map = "<leader>l<C-g><C-h>",
        desc = "Grep the docs (with regex), add to loclist",
        callback = function()
            eg.grep_help(grep_smart_case, sys_help_ladd)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-grep-bufs-n)",
        map = "<leader>qgu",
        desc = "Grep open bufs, new qflist",
        callback = function()
            eg.grep_bufs(grep_smart_case, sys_new)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-grep-bufs-r)",
        map = "<leader>qGu",
        desc = "Grep open bufs, replace qflist",
        callback = function()
            eg.grep_bufs(grep_smart_case, sys_replace)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-grep-bufs-a)",
        map = "<leader>q<C-g>u",
        desc = "Grep open bufs, add to qflist",
        callback = function()
            eg.grep_bufs(grep_smart_case, sys_add)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-grep-BUFS-n)",
        map = "<leader>qgU",
        desc = "Grep open bufs (case-sensitive), new qflist",
        callback = function()
            eg.grep_bufs(grep_case_sensitive, sys_new)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-grep-BUFS-r)",
        map = "<leader>qGU",
        desc = "Grep open bufs (case-sensitive), replace qflist",
        callback = function()
            eg.grep_bufs(grep_case_sensitive, sys_replace)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-grep-BUFS-a)",
        map = "<leader>q<C-g>U",
        desc = "Grep open bufs (case-sensitive), add to qflist",
        callback = function()
            eg.grep_bufs(grep_case_sensitive, sys_add)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-grep-bufsX-n)",
        map = "<leader>qg<C-u>",
        desc = "Grep open bufs (with regex), new qflist",
        callback = function()
            eg.grep_bufs({}, sys_new)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-grep-bufsX-r)",
        map = "<leader>qG<C-u>",
        desc = "Grep open bufs (with regex), replace qflist",
        callback = function()
            eg.grep_bufs({}, sys_replace)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-grep-bufsX-a)",
        map = "<leader>q<C-g><C-u>",
        desc = "Grep open bufs (with regex), add to qflist",
        callback = function()
            eg.grep_bufs({}, sys_add)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-grep-cbuf-n)",
        map = "<leader>lgu",
        desc = "Grep cur buf, new loclist",
        callback = function()
            eg.grep_cbuf(grep_smart_case, sys_lnew)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-grep-cbuf-r)",
        map = "<leader>lGu",
        desc = "Grep cur buf, replace loclist",
        callback = function()
            eg.grep_cbuf(grep_smart_case, sys_lreplace)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-grep-cbuf-a)",
        map = "<leader>l<C-g>u",
        desc = "Grep cur buf, add to loclist",
        callback = function()
            eg.grep_cbuf(grep_smart_case, sys_ladd)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-grep-CBUF-n)",
        map = "<leader>lgD",
        desc = "Grep cur buf (case-sensitive), new loclist",
        callback = function()
            eg.grep_cbuf(grep_case_sensitive, sys_lnew)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-grep-CBUF-r)",
        map = "<leader>lGU",
        desc = "Grep cur buf (case-sensitive), replace loclist",
        callback = function()
            eg.grep_cbuf(grep_case_sensitive, sys_lreplace)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-grep-CBUF-a)",
        map = "<leader>l<C-g>U",
        desc = "Grep cur buf (case-sensitive), add to loclist",
        callback = function()
            eg.grep_cbuf(grep_case_sensitive, sys_ladd)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-grep-cbufX-n)",
        map = "<leader>lg<C-u>",
        desc = "Grep cur buf (with regex), new loclist",
        callback = function()
            eg.grep_cbuf({}, sys_lnew)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-grep-cbufX-r)",
        map = "<leader>lG<C-u>",
        desc = "Grep cur buf (with regex), replace loclist",
        callback = function()
            eg.grep_cbuf({}, sys_lreplace)
        end,
    },
    {
        modes = { "n", "x" },
        plug = "<Plug>(qf-rancher-grep-cbufX-a)",
        map = "<leader>l<C-g><C-u>",
        desc = "Grep cur buf (with regex), add to loclist",
        callback = function()
            eg.grep_cbuf({}, sys_ladd)
        end,
    },

    -------------------------
    --- OPEN/CLOSE/RESIZE ---
    -------------------------

    {
        modes = { "n" },
        plug = "<Plug>(qf-rancher-open-qf-list)",
        map = "<leader>qp",
        desc = "Open the quickfix list",
        callback = function()
            local height = vim.v.count > 0 and vim.v.count or nil
            eo.open_qflist({ always_resize = true, height = height })
        end,
    },
    {
        modes = { "n" },
        plug = "<Plug>(qf-rancher-close-qf-list)",
        map = "<leader>qo",
        desc = "Close the quickfix list",
        callback = function()
            eo.close_qflist()
        end,
    },
    {
        modes = { "n" },
        plug = "<Plug>(qf-rancher-toggle-qf-list)",
        map = "<leader>qq",
        desc = "Toggle the quickfix list",
        callback = function()
            if not eo.open_qflist() then
                eo.close_qflist()
            end
        end,
    },
    {
        modes = { "n" },
        plug = "<Plug>(qf-rancher-open-loclist)",
        map = "<leader>lp",
        desc = "Open the location list",
        callback = function()
            local height = vim.v.count > 0 and vim.v.count or nil
            eo.open_loclist({ always_resize = true, height = height })
        end,
    },
    {
        modes = { "n" },
        plug = "<Plug>(qf-rancher-close-loclist)",
        map = "<leader>lo",
        desc = "Close the location list",
        callback = function()
            eo.close_loclist()
        end,
    },
    {
        modes = { "n" },
        plug = "<Plug>(qf-rancher-toggle-loclist)",
        map = "<leader>ll",
        desc = "Toggle the location list",
        callback = function()
            if not eo.open_loclist({ suppress_errors = true }) then
                eo.close_loclist()
            end
        end,
    },

    ------------------
    --- NAVIGATION ---
    ------------------

    {
        modes = { "n" },
        plug = "<Plug>(qf-rancher-qf-prev)",
        map = "[q",
        desc = "Go to a previous qf entry",
        callback = function()
            en.q_prev(vim.v.count1)
        end,
    },
    {
        modes = { "n" },
        plug = "<Plug>(qf-rancher-qf-next)",
        map = "]q",
        desc = "Go to a later qf entry",
        callback = function()
            en.q_next(vim.v.count1)
        end,
    },
    {
        modes = { "n" },
        plug = "<Plug>(qf-rancher-qf-pfile)",
        map = "[<C-q>",
        desc = "Go to the previous qf file",
        callback = function()
            en.q_pfile(vim.v.count1)
        end,
    },
    {
        modes = { "n" },
        plug = "<Plug>(qf-rancher-qf-nfile)",
        map = "]<C-q>",
        desc = "Go to the next qf file",
        callback = function()
            en.q_nfile(vim.v.count1)
        end,
    },
    {
        modes = { "n" },
        plug = "<Plug>(qf-rancher-qf-jump)",
        map = "<leader>q<C-q>",
        desc = "Jump to the qflist",
        callback = function()
            en.q_jump(vim.v.count)
        end,
    },
    {
        modes = { "n" },
        plug = "<Plug>(qf-rancher-ll-prev)",
        map = "[l",
        desc = "Go to a previous loclist entry",
        callback = function()
            en.l_prev(vim.v.count1)
        end,
    },
    {
        modes = { "n" },
        plug = "<Plug>(qf-rancher-ll-next)",
        map = "]l",
        desc = "Go to a later loclist entry",
        callback = function()
            en.l_next(vim.v.count1)
        end,
    },
    {
        modes = { "n" },
        plug = "<Plug>(qf-rancher-ll-pfile)",
        map = "[<C-l>",
        desc = "Go to the previous loclist file",
        callback = function()
            en.l_pfile(vim.v.count1)
        end,
    },
    {
        modes = { "n" },
        plug = "<Plug>(qf-rancher-ll-nfile)",
        map = "]<C-l>",
        desc = "Go to the next loclist file",
        callback = function()
            en.l_nfile(vim.v.count1)
        end,
    },
    {
        modes = { "n" },
        plug = "<Plug>(qf-rancher-ll-jump)",
        map = "<leader>l<C-l>",
        desc = "Jump to the loclist",
        callback = function()
            en.l_jump(vim.v.count)
        end,
    },

    -------------
    --- STACK ---
    -------------

    {
        modes = { "n" },
        plug = "<Plug>(qf-rancher-qf-older)",
        map = "<leader>q[",
        desc = "Go to an older qflist",
        callback = function()
            es.q_older(vim.v.count1)
        end,
    },
    {
        modes = { "n" },
        plug = "<Plug>(qf-rancher-qf-newer)",
        map = "<leader>q]",
        desc = "Go to a newer qflist",
        callback = function()
            es.q_newer(vim.v.count1)
        end,
    },
    {
        modes = { "n" },
        plug = "<Plug>(qf-rancher-qf-history)",
        map = "<leader>qQ",
        desc = "View or jump within the quickfix history",
        callback = function()
            es.q_history(vim.v.count)
        end,
    },
    {
        modes = { "n" },
        plug = "<Plug>(qf-rancher-qf-del)",
        map = "<leader>qe",
        desc = "Delete a list from the quickfix stack",
        callback = function()
            es.q_del(vim.v.count)
        end,
    },
    {
        modes = { "n" },
        plug = "<Plug>(qf-rancher-qf-del-all)",
        map = "<leader>qE",
        desc = "Delete all items from the quickfix stack",
        callback = function()
            es.q_del_all()
        end,
    },
    {
        modes = { "n" },
        plug = "<Plug>(qf-rancher-ll-older)",
        map = "<leader>l[",
        desc = "Go to an older location list",
        callback = function()
            es.l_older(vim.v.count1)
        end,
    },
    {
        modes = { "n" },
        plug = "<Plug>(qf-rancher-ll-newer)",
        map = "<leader>l]",
        desc = "Go to a newer location list",
        callback = function()
            es.l_newer(vim.v.count1)
        end,
    },
    {
        modes = { "n" },
        plug = "<Plug>(qf-rancher-ll-history)",
        map = "<leader>lL",
        desc = "View or jump within the loclist history",
        callback = function()
            es.l_history(vim.v.count)
        end,
    },
    {
        modes = { "n" },
        plug = "<Plug>(qf-rancher-ll-del)",
        map = "<leader>le",
        desc = "Delete a list from the loclist stack",
        callback = function()
            es.l_del(vim.v.count)
        end,
    },
    {
        modes = { "n" },
        plug = "<Plug>(qf-rancher-ll-del-all)",
        map = "<leader>lE",
        desc = "Delete all items from the loclist stack",
        callback = function()
            es.l_del_all()
        end,
    },
}

for _, km in ipairs(rancher_keymaps) do
    for _, mode in ipairs(km.modes) do
        vim.api.nvim_set_keymap(mode, km.plug, "<nop>", {
            callback = km.callback,
            desc = km.desc,
            noremap = true,
        })
    end
end

if vim.g.qfrancher_setdefaultmaps then
    for _, km in ipairs(rancher_keymaps) do
        for _, mode in ipairs(km.modes) do
            vim.api.nvim_set_keymap(mode, km.map, km.plug, {
                desc = km.desc,
                noremap = true,
            })
        end
    end

    -- Since the plug logic remaps "<nop>", undo that here
    vim.keymap.del("n", "<nop>")
end

------------
--- GREP ---
------------

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
            if arg:match("^/") then
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
