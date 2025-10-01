--- NOTE: In order for the defer require to work, all function calls must be inside of
--- anonymous functions. If you pass, for example, eo.closeqflist as a function reference, eo
--- needs to be evaluated at command creation, defeating the purpose of the defer require

--------------------------
--- Map and Cmd Pieces ---
--------------------------

local actions = { "new", "replace", "add" }
local default_action = "new"

local sys_async = { async = true, timeout = 4000 } --- @type QfRancherSystemOpts

local in_vimsmart = { input_type = "vimsmart" } --- @type QfRancherInputOpts
local in_sensitive = { input_type = "sensitive" } --- @type QfRancherInputOpts
local in_regex = { input_type = "regex" } --- @type QfRancherInputOpts

local qflist_new = { is_loclist = false, action = "new" } --- @type QfRancherOutputOpts
local qflist_replace = { is_loclist = false, action = "replace" } --- @type QfRancherOutputOpts
local qflist_add = { is_loclist = false, action = "add" } --- @type QfRancherOutputOpts
local llist_new = { is_loclist = true, action = "new" } --- @type QfRancherOutputOpts
local llist_replace = { is_loclist = true, action = "replace" } --- @type QfRancherOutputOpts
local llist_add = { is_loclist = true, action = "add" } --- @type QfRancherOutputOpts

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

local ed = Qfr_Defer_Require("mjm.error-list-diag")
local ef = Qfr_Defer_Require("mjm.error-list-filter")
local eg = Qfr_Defer_Require("mjm.error-list-grep")
local en = Qfr_Defer_Require("mjm.error-list-nav-action")
local eo = Qfr_Defer_Require("mjm.error-list-open")
local es = Qfr_Defer_Require("mjm.error-list-stack")
local et = Qfr_Defer_Require("mjm.error-list-sort")

local grep_smart_case = { literal = true, smart_case = true }
local grep_case_sensitive = { literal = true }

-- TODO: With 280 keymaps (so far), we will indeed be needing a way for the user to customize the
-- various prefixes

local nn = { "n" }
local nx = { "n", "x" }
local pqfr = "<Plug>(qf-rancher"
local qp = "<leader>q"
local lp = "<leader>l"
local sc = " (smartcase)"
local cs = " (case sensitive)"
local rx = " (regex)"
local n = ", new"
local r = ", replace"
local a = ", add"

local keep = { keep = true }
local nokeep = { keep = false }

--- The keymaps need to all be set here to avoid eagerly requiring other modules
--- I have not been able to find a way to build the list at runtime without it being hard to read
--- and non-trivially affecting startup time

--- @alias QfRancherMapData{[1]:string[], [2]:string, [3]:string, [4]: string, [5]: function}

-- stylua: ignore
--- @type QfRancherMapData[]
local rancher_keymaps = {
    { nx, "<nop>", "<leader>q", "Avoid falling back to defaults", nil },
    { nx, "<nop>", "<leader>l", "Avoid falling back to defaults", nil },

    -------------------
    --- DIAGNOSTICS ---
    -------------------

    { nx, "<nop>", "<leader>qi", "Avoid falling back to defaults", nil },
    { nx, "<nop>", "<leader>li", "Avoid falling back to defaults", nil },

    { nn, pqfr.. "Qdiags-n-hint",  qp.."in", "All buffer diagnostics min hint"..n,         function() ed.diags("hint", { action = "new", is_loclist = false }) end },
    { nn, pqfr.. "Qdiags-n-info",  qp.."if", "All buffer diagnostics min info"..n,         function() ed.diags("info", { action = "new", is_loclist = false }) end },
    { nn, pqfr.. "Qdiags-n-warn",  qp.."iw", "All buffer diagnostics min warn"..n,         function() ed.diags("warn", { action = "new" , is_loclist = false}) end },
    { nn, pqfr.. "Qdiags-n-error", qp.."ie", "All buffer diagnostics min error"..n,        function() ed.diags("error", { action = "new", is_loclist = false}) end },
    { nn, pqfr.. "Qdiags-n-top",   qp.."it", "All buffer diagnostics top severity"..n,     function() ed.diags("top", { action = "new", is_loclist = false }) end },

    { nn, pqfr.. "Ldiags-n-hint",  lp.."in", "Cur win diagnostics min hint"..n,            function() ed.diags("hint", { action = "new", is_loclist = true }) end },
    { nn, pqfr.. "Ldiags-n-info",  lp.."if", "Cur win diagnostics min info"..n,            function() ed.diags("info", { action = "new", is_loclist = true }) end },
    { nn, pqfr.. "Ldiags-n-warn",  lp.."iw", "Cur win diagnostics min warn"..n,            function() ed.diags("warn", { action = "new" , is_loclist = true}) end },
    { nn, pqfr.. "Ldiags-n-error", lp.."ie", "Cur win diagnostics min error"..n,           function() ed.diags("error", { action = "new", is_loclist = true}) end },
    { nn, pqfr.. "Ldiags-n-top",   lp.."it", "Cur win diagnostics top severity"..n,        function() ed.diags("top", { action = "new", is_loclist = true }) end },

    { nn, pqfr.. "Qdiags-r-hint",  qp.."In", "All buffer diagnostics min hint"..r,         function() ed.diags("hint", { action = "replace", is_loclist = false }) end },
    { nn, pqfr.. "Qdiags-r-info",  qp.."If", "All buffer diagnostics min info"..r,         function() ed.diags("info", { action = "replace", is_loclist = false }) end },
    { nn, pqfr.. "Qdiags-r-warn",  qp.."Iw", "All buffer diagnostics min warn"..r,         function() ed.diags("warn", { action = "replace" , is_loclist = false}) end },
    { nn, pqfr.. "Qdiags-r-error", qp.."Ie", "All buffer diagnostics min error"..r,        function() ed.diags("error", { action = "replace", is_loclist = false}) end },
    { nn, pqfr.. "Qdiags-r-top",   qp.."It", "All buffer diagnostics top severity"..r,     function() ed.diags("top", { action = "replace", is_loclist = false }) end },

    { nn, pqfr.. "Ldiags-r-hint",  lp.."In", "Cur win diagnostics min hint"..r,            function() ed.diags("hint", { action = "replace", is_loclist = true }) end },
    { nn, pqfr.. "Ldiags-r-info",  lp.."If", "Cur win diagnostics min info"..r,            function() ed.diags("info", { action = "replace", is_loclist = true }) end },
    { nn, pqfr.. "Ldiags-r-warn",  lp.."Iw", "Cur win diagnostics min warn"..r,            function() ed.diags("warn", { action = "replace" , is_loclist = true}) end },
    { nn, pqfr.. "Ldiags-r-error", lp.."Ie", "Cur win diagnostics min error"..r,           function() ed.diags("error", { action = "replace", is_loclist = true}) end },
    { nn, pqfr.. "Ldiags-r-top",   lp.."It", "Cur win diagnostics top severity"..r,        function() ed.diags("top", { action = "replace", is_loclist = true }) end },

    { nn, pqfr.. "Qdiags-a-hint",  qp.."<C-i>n", "All buffer diagnostics min hint"..a,     function() ed.diags("hint", { action = "add", is_loclist = false }) end },
    { nn, pqfr.. "Qdiags-a-info",  qp.."<C-i>f", "All buffer diagnostics min info"..a,     function() ed.diags("info", { action = "add", is_loclist = false }) end },
    { nn, pqfr.. "Qdiags-a-warn",  qp.."<C-i>w", "All buffer diagnostics min warn"..a,     function() ed.diags("warn", { action = "add" , is_loclist = false}) end },
    { nn, pqfr.. "Qdiags-a-error", qp.."<C-i>e", "All buffer diagnostics min error"..a,    function() ed.diags("error", { action = "add", is_loclist = false}) end },
    { nn, pqfr.. "Qdiags-a-top",   qp.."<C-i>t", "All buffer diagnostics top severity"..a, function() ed.diags("top", { action = "add", is_loclist = false }) end },

    { nn, pqfr.. "Ldiags-a-hint",  lp.."<C-i>n", "Cur win diagnostics min hint"..a,        function() ed.diags("hint", { action = "add", is_loclist = true }) end },
    { nn, pqfr.. "Ldiags-a-info",  lp.."<C-i>f", "Cur win diagnostics min info"..a,        function() ed.diags("info", { action = "add", is_loclist = true }) end },
    { nn, pqfr.. "Ldiags-a-warn",  lp.."<C-i>w", "Cur win diagnostics min warn"..a,        function() ed.diags("warn", { action = "add" , is_loclist = true}) end },
    { nn, pqfr.. "Ldiags-a-error", lp.."<C-i>e", "Cur win diagnostics min error"..a,       function() ed.diags("error", { action = "add", is_loclist = true}) end },
    { nn, pqfr.. "Ldiags-a-top",   lp.."<C-i>t", "Cur win diagnostics top severity"..a,    function() ed.diags("top", { action = "add", is_loclist = true }) end },

    { nn, pqfr.. "Qdiags-n-HINT",  qp.."iN", "All buffer diagnostics only hint"..n,        function() ed.diags("hint_only", { action = "new", is_loclist = false }) end },
    { nn, pqfr.. "Qdiags-n-INFO",  qp.."iF", "All buffer diagnostics only info"..n,        function() ed.diags("info_only", { action = "new", is_loclist = false }) end },
    { nn, pqfr.. "Qdiags-n-WARN",  qp.."iW", "All buffer diagnostics only warn"..n,        function() ed.diags("warn_only", { action = "new" , is_loclist = false}) end },
    { nn, pqfr.. "Qdiags-n-ERROR", qp.."iE", "All buffer diagnostics only error"..n,       function() ed.diags("error_only", { action = "new", is_loclist = false}) end },
    { nn, pqfr.. "Qdiags-n-TOP",   qp.."iT", "All buffer diagnostics top severity"..n,     function() ed.diags("top", { action = "new", is_loclist = false }) end },

    { nn, pqfr.. "Ldiags-n-HINT",  lp.."iN", "Cur win diagnostics only hint"..n,           function() ed.diags("hint_only", { action = "new", is_loclist = true }) end },
    { nn, pqfr.. "Ldiags-n-INFO",  lp.."iF", "Cur win diagnostics only info"..n,           function() ed.diags("info_only", { action = "new", is_loclist = true }) end },
    { nn, pqfr.. "Ldiags-n-WARN",  lp.."iW", "Cur win diagnostics only warn"..n,           function() ed.diags("warn_only", { action = "new" , is_loclist = true}) end },
    { nn, pqfr.. "Ldiags-n-ERROR", lp.."iE", "Cur win diagnostics only error"..n,          function() ed.diags("error_only", { action = "new", is_loclist = true}) end },
    { nn, pqfr.. "Ldiags-n-TOP",   lp.."iT", "Cur win diagnostics top severity"..n,        function() ed.diags("top", { action = "new", is_loclist = true }) end },

    { nn, pqfr.. "Qdiags-r-HINT",  qp.."IN", "All buffer diagnostics only hint"..r,        function() ed.diags("hint_only", { action = "replace", is_loclist = false }) end },
    { nn, pqfr.. "Qdiags-r-INFO",  qp.."IF", "All buffer diagnostics only info"..r,        function() ed.diags("info_only", { action = "replace", is_loclist = false }) end },
    { nn, pqfr.. "Qdiags-r-WARN",  qp.."IW", "All buffer diagnostics only warn"..r,        function() ed.diags("warn_only", { action = "replace" , is_loclist = false}) end },
    { nn, pqfr.. "Qdiags-r-ERROR", qp.."IE", "All buffer diagnostics only error"..r,       function() ed.diags("error_only", { action = "replace", is_loclist = false}) end },
    { nn, pqfr.. "Qdiags-r-TOP",   qp.."IT", "All buffer diagnostics top severity"..r,     function() ed.diags("top", { action = "replace", is_loclist = false }) end },

    { nn, pqfr.. "Ldiags-r-HINT",  lp.."IN", "Cur win diagnostics only hint"..r,           function() ed.diags("hint_only", { action = "replace", is_loclist = true }) end },
    { nn, pqfr.. "Ldiags-r-INFO",  lp.."IF", "Cur win diagnostics only info"..r,           function() ed.diags("info_only", { action = "replace", is_loclist = true }) end },
    { nn, pqfr.. "Ldiags-r-WARN",  lp.."IW", "Cur win diagnostics only warn"..r,           function() ed.diags("warn_only", { action = "replace" , is_loclist = true}) end },
    { nn, pqfr.. "Ldiags-r-ERROR", lp.."IE", "Cur win diagnostics only error"..r,          function() ed.diags("error_only", { action = "replace", is_loclist = true}) end },
    { nn, pqfr.. "Ldiags-r-TOP",   lp.."IT", "Cur win diagnostics top severity"..r,        function() ed.diags("top", { action = "replace", is_loclist = true }) end },

    { nn, pqfr.. "Qdiags-a-HINT",  qp.."<C-i>N", "All buffer diagnostics only hint"..a,    function() ed.diags("hint_only", { action = "add", is_loclist = false }) end },
    { nn, pqfr.. "Qdiags-a-INFO",  qp.."<C-i>F", "All buffer diagnostics only info"..a,    function() ed.diags("info_only", { action = "add", is_loclist = false }) end },
    { nn, pqfr.. "Qdiags-a-WARN",  qp.."<C-i>W", "All buffer diagnostics only warn"..a,    function() ed.diags("warn_only", { action = "add" , is_loclist = false}) end },
    { nn, pqfr.. "Qdiags-a-ERROR", qp.."<C-i>E", "All buffer diagnostics only error"..a,   function() ed.diags("error_only", { action = "add", is_loclist = false}) end },
    { nn, pqfr.. "Qdiags-a-TOP",   qp.."<C-i>T", "All buffer diagnostics top severity"..a, function() ed.diags("top", { action = "add", is_loclist = false }) end },

    { nn, pqfr.. "Ldiags-a-HINT",  lp.."<C-i>N", "Cur win diagnostics only hint"..a,       function() ed.diags("hint_only", { action = "add", is_loclist = true }) end },
    { nn, pqfr.. "Ldiags-a-INFO",  lp.."<C-i>F", "Cur win diagnostics only info"..a,       function() ed.diags("info_only", { action = "add", is_loclist = true }) end },
    { nn, pqfr.. "Ldiags-a-WARN",  lp.."<C-i>W", "Cur win diagnostics only warn"..a,       function() ed.diags("warn_only", { action = "add" , is_loclist = true}) end },
    { nn, pqfr.. "Ldiags-a-ERROR", lp.."<C-i>E", "Cur win diagnostics only error"..a,      function() ed.diags("error_only", { action = "add", is_loclist = true}) end },
    { nn, pqfr.. "Ldiags-a-TOP",   lp.."<C-i>T", "Cur win diagnostics top severity"..a,    function() ed.diags("top", { action = "add", is_loclist = true }) end },

    --------------
    --- FILTER ---
    --------------

    { nx, "<nop>", "<leader>qk",     "Avoid falling back to defaults", nil },
    { nx, "<nop>", "<leader>qr",     "Avoid falling back to defaults", nil },
    { nx, "<nop>", "<leader>qK",     "Avoid falling back to defaults", nil },
    { nx, "<nop>", "<leader>qR",     "Avoid falling back to defaults", nil },
    { nx, "<nop>", "<leader>q<c-k>", "Avoid falling back to defaults", nil },
    { nx, "<nop>", "<leader>q<c-r>", "Avoid falling back to defaults", nil },

    { nx, "<nop>", "<leader>lk",     "Avoid falling back to defaults", nil },
    { nx, "<nop>", "<leader>lr",     "Avoid falling back to defaults", nil },
    { nx, "<nop>", "<leader>lK",     "Avoid falling back to defaults", nil },
    { nx, "<nop>", "<leader>lR",     "Avoid falling back to defaults", nil },
    { nx, "<nop>", "<leader>l<c-k>", "Avoid falling back to defaults", nil },
    { nx, "<nop>", "<leader>l<c-r>", "Avoid falling back to defaults", nil },

    --- Cfilter ---

    { nx, pqfr.."-Qfilter-n-cfilter)",   qp.."kl",         "Qfilter cfilter"..n..sc,  function() ef.filter("cfilter", keep, { input_type = "vimsmart" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-r-cfilter)",   qp.."Kl",         "Qfilter cfilter"..r..sc,  function() ef.filter("cfilter", keep, { input_type = "vimsmart" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-a-cfilter)",   qp.."<C-k>l",     "Qfilter cfilter"..a..sc,  function() ef.filter("cfilter", keep, { input_type = "vimsmart" }, { action = "add", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-n-cfilter)",  qp.."rl",         "Qfilter! cfilter"..n..sc, function() ef.filter("cfilter", nokeep, { input_type = "vimsmart" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-r-cfilter)",  qp.."Rl",         "Qfilter! cfilter"..r..sc, function() ef.filter("cfilter", nokeep, { input_type = "vimsmart" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-a-cfilter)",  qp.."<C-r>l",     "Qfilter! cfilter"..a..sc, function() ef.filter("cfilter", nokeep, { input_type = "vimsmart" }, { action = "add", is_loclist = false }) end},

    { nx, pqfr.."-Qfilter-n-CFILTER)",   qp.."kL",         "Qfilter cfilter"..n..cs,  function() ef.filter("cfilter", keep, { input_type = "sensitive" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-r-CFILTER)",   qp.."KL",         "Qfilter cfilter"..r..cs,  function() ef.filter("cfilter", keep, { input_type = "sensitive" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-a-CFILTER)",   qp.."<C-k>L",     "Qfilter cfilter"..a..cs,  function() ef.filter("cfilter", keep, { input_type = "sensitive" }, { action = "add", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-n-CFILTER)",  qp.."rL",         "Qfilter! cfilter"..n..cs, function() ef.filter("cfilter", nokeep, { input_type = "sensitive" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-r-CFILTER)",  qp.."RL",         "Qfilter! cfilter"..r..cs, function() ef.filter("cfilter", nokeep, { input_type = "sensitive" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-a-CFILTER)",  qp.."<C-r>L",     "Qfilter! cfilter"..a..cs, function() ef.filter("cfilter", nokeep, { input_type = "sensitive" }, { action = "add", is_loclist = false }) end},

    { nx, pqfr.."-Qfilter-n-cfilterX)",  qp.."k<C-l>",     "Qfilter cfilter"..n..rx,  function() ef.filter("cfilter", keep, { input_type = "regex" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-r-cfilterX)",  qp.."K<C-l>",     "Qfilter cfilter"..r..rx,  function() ef.filter("cfilter", keep, { input_type = "regex" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-a-cfilterX)",  qp.."<C-k><C-l>", "Qfilter cfilter"..a..rx,  function() ef.filter("cfilter", keep, { input_type = "regex" }, { action = "add", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-n-cfilterX)", qp.."r<C-l>",     "Qfilter! cfilter"..n..rx, function() ef.filter("cfilter", nokeep, { input_type = "regex" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-r-cfilterX)", qp.."R<C-l>",     "Qfilter! cfilter"..r..rx, function() ef.filter("cfilter", nokeep, { input_type = "regex" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-a-cfilterX)", qp.."<C-r><C-l>", "Qfilter! cfilter"..a..rx, function() ef.filter("cfilter", nokeep, { input_type = "regex" }, { action = "add", is_loclist = false }) end},

    { nx, pqfr.."-Lfilter-n-cfilter)",   lp.."kl",         "Lfilter cfilter"..n..sc,  function() ef.filter("cfilter", keep, { input_type = "vimsmart" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-r-cfilter)",   lp.."Kl",         "Lfilter cfilter"..r..sc,  function() ef.filter("cfilter", keep, { input_type = "vimsmart" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-a-cfilter)",   lp.."<C-k>l",     "Lfilter cfilter"..a..sc,  function() ef.filter("cfilter", keep, { input_type = "vimsmart" }, { action = "add", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-n-cfilter)",  lp.."rl",         "Lfilter! cfilter"..n..sc, function() ef.filter("cfilter", nokeep, { input_type = "vimsmart" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-r-cfilter)",  lp.."Rl",         "Lfilter! cfilter"..r..sc, function() ef.filter("cfilter", nokeep, { input_type = "vimsmart" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-a-cfilter)",  lp.."<C-r>l",     "Lfilter! cfilter"..a..sc, function() ef.filter("cfilter", nokeep, { input_type = "vimsmart" }, { action = "add", is_loclist = true }) end},

    { nx, pqfr.."-Lfilter-n-CFILTER)",   lp.."kL",         "Lfilter cfilter"..n..cs,  function() ef.filter("cfilter", keep, { input_type = "sensitive" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-r-CFILTER)",   lp.."KL",         "Lfilter cfilter"..r..cs,  function() ef.filter("cfilter", keep, { input_type = "sensitive" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-a-CFILTER)",   lp.."<C-k>L",     "Lfilter cfilter"..a..cs,  function() ef.filter("cfilter", keep, { input_type = "sensitive" }, { action = "add", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-n-CFILTER)",  lp.."rL",         "Lfilter! cfilter"..n..cs, function() ef.filter("cfilter", nokeep, { input_type = "sensitive" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-r-CFILTER)",  lp.."RL",         "Lfilter! cfilter"..r..cs, function() ef.filter("cfilter", nokeep, { input_type = "sensitive" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-a-CFILTER)",  lp.."<C-r>L",     "Lfilter! cfilter"..a..cs, function() ef.filter("cfilter", nokeep, { input_type = "sensitive" }, { action = "add", is_loclist = true }) end},

    { nx, pqfr.."-Lfilter-n-cfilterX)",  lp.."k<C-l>",     "Lfilter cfilter"..n..rx,  function() ef.filter("cfilter", keep, { input_type = "regex" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-r-cfilterX)",  lp.."K<C-l>",     "Lfilter cfilter"..r..rx,  function() ef.filter("cfilter", keep, { input_type = "regex" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-a-cfilterX)",  lp.."<C-k><C-l>", "Lfilter cfilter"..a..rx,  function() ef.filter("cfilter", keep, { input_type = "regex" }, { action = "add", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-n-cfilterX)", lp.."r<C-l>",     "Lfilter! cfilter"..n..rx, function() ef.filter("cfilter", nokeep, { input_type = "regex" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-r-cfilterX)", lp.."R<C-l>",     "Lfilter! cfilter"..r..rx, function() ef.filter("cfilter", nokeep, { input_type = "regex" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-a-cfilterX)", lp.."<C-r><C-l>", "Lfilter! cfilter"..a..rx, function() ef.filter("cfilter", nokeep, { input_type = "regex" }, { action = "add", is_loclist = true }) end},

    --- Fname ---

    { nx, pqfr.."-Qfilter-n-fname)",     qp.."kf",         "Qfilter fname"..n..sc,    function() ef.filter("fname", keep, { input_type = "vimsmart" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-r-fname)",     qp.."Kf",         "Qfilter fname"..r..sc,    function() ef.filter("fname", keep, { input_type = "vimsmart" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-a-fname)",     qp.."<C-k>f",     "Qfilter fname"..a..sc,    function() ef.filter("fname", keep, { input_type = "vimsmart" }, { action = "add", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-n-fname)",    qp.."rf",         "Qfilter! fname"..n..sc,   function() ef.filter("fname", nokeep, { input_type = "vimsmart" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-r-fname)",    qp.."Rf",         "Qfilter! fname"..r..sc,   function() ef.filter("fname", nokeep, { input_type = "vimsmart" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-a-fname)",    qp.."<C-r>f",     "Qfilter! fname"..a..sc,   function() ef.filter("fname", nokeep, { input_type = "vimsmart" }, { action = "add", is_loclist = false }) end},

    { nx, pqfr.."-Qfilter-n-FNAME)",     qp.."kF",         "Qfilter fname"..n..cs,    function() ef.filter("fname", keep, { input_type = "sensitive" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-r-FNAME)",     qp.."KF",         "Qfilter fname"..r..cs,    function() ef.filter("fname", keep, { input_type = "sensitive" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-a-FNAME)",     qp.."<C-k>F",     "Qfilter fname"..a..cs,    function() ef.filter("fname", keep, { input_type = "sensitive" }, { action = "add", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-n-FNAME)",    qp.."rF",         "Qfilter! fname"..n..cs,   function() ef.filter("fname", nokeep, { input_type = "sensitive" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-r-FNAME)",    qp.."RF",         "Qfilter! fname"..r..cs,   function() ef.filter("fname", nokeep, { input_type = "sensitive" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-a-FNAME)",    qp.."<C-r>F",     "Qfilter! fname"..a..cs,   function() ef.filter("fname", nokeep, { input_type = "sensitive" }, { action = "add", is_loclist = false }) end},

    { nx, pqfr.."-Qfilter-n-fnameX)",    qp.."k<C-f>",     "Qfilter fname"..n..rx,    function() ef.filter("fname", keep, { input_type = "regex" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-r-fnameX)",    qp.."K<C-f>",     "Qfilter fname"..r..rx,    function() ef.filter("fname", keep, { input_type = "regex" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-a-fnameX)",    qp.."<C-k><C-f>", "Qfilter fname"..a..rx,    function() ef.filter("fname", keep, { input_type = "regex" }, { action = "add", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-n-fnameX)",   qp.."r<C-f>",     "Qfilter! fname"..n..rx,   function() ef.filter("fname", nokeep, { input_type = "regex" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-r-fnameX)",   qp.."R<C-f>",     "Qfilter! fname"..r..rx,   function() ef.filter("fname", nokeep, { input_type = "regex" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-a-fnameX)",   qp.."<C-r><C-f>", "Qfilter! fname"..a..rx,   function() ef.filter("fname", nokeep, { input_type = "regex" }, { action = "add", is_loclist = false }) end},

    { nx, pqfr.."-Lfilter-n-fname)",     lp.."kf",         "Lfilter fname"..n..sc,    function() ef.filter("fname", keep, { input_type = "vimsmart" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-r-fname)",     lp.."Kf",         "Lfilter fname"..r..sc,    function() ef.filter("fname", keep, { input_type = "vimsmart" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-a-fname)",     lp.."<C-k>f",     "Lfilter fname"..a..sc,    function() ef.filter("fname", keep, { input_type = "vimsmart" }, { action = "add", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-n-fname)",    lp.."rf",         "Lfilter! fname"..n..sc,   function() ef.filter("fname", nokeep, { input_type = "vimsmart" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-r-fname)",    lp.."Rf",         "Lfilter! fname"..r..sc,   function() ef.filter("fname", nokeep, { input_type = "vimsmart" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-a-fname)",    lp.."<C-r>f",     "Lfilter! fname"..a..sc,   function() ef.filter("fname", nokeep, { input_type = "vimsmart" }, { action = "add", is_loclist = true }) end},

    { nx, pqfr.."-Lfilter-n-FNAME)",     lp.."kF",         "Lfilter fname"..n..cs,    function() ef.filter("fname", keep, { input_type = "sensitive" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-r-FNAME)",     lp.."KF",         "Lfilter fname"..r..cs,    function() ef.filter("fname", keep, { input_type = "sensitive" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-a-FNAME)",     lp.."<C-k>F",     "Lfilter fname"..a..cs,    function() ef.filter("fname", keep, { input_type = "sensitive" }, { action = "add", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-n-FNAME)",    lp.."rF",         "Lfilter! fname"..n..cs,   function() ef.filter("fname", nokeep, { input_type = "sensitive" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-r-FNAME)",    lp.."RF",         "Lfilter! fname"..r..cs,   function() ef.filter("fname", nokeep, { input_type = "sensitive" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-a-FNAME)",    lp.."<C-r>F",     "Lfilter! fname"..a..cs,   function() ef.filter("fname", nokeep, { input_type = "sensitive" }, { action = "add", is_loclist = true }) end},

    { nx, pqfr.."-Lfilter-n-fnameX)",    lp.."k<C-f>",     "Lfilter fname"..n..rx,    function() ef.filter("fname", keep, { input_type = "regex" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-r-fnameX)",    lp.."K<C-f>",     "Lfilter fname"..r..rx,    function() ef.filter("fname", keep, { input_type = "regex" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-a-fnameX)",    lp.."<C-k><C-f>", "Lfilter fname"..a..rx,    function() ef.filter("fname", keep, { input_type = "regex" }, { action = "add", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-n-fnameX)",   lp.."r<C-f>",     "Lfilter! fname"..n..rx,   function() ef.filter("fname", nokeep, { input_type = "regex" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-r-fnameX)",   lp.."R<C-f>",     "Lfilter! fname"..r..rx,   function() ef.filter("fname", nokeep, { input_type = "regex" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-a-fnameX)",   lp.."<C-r><C-f>", "Lfilter! fname"..a..rx,   function() ef.filter("fname", nokeep, { input_type = "regex" }, { action = "add", is_loclist = true }) end},

    --- Text ---

    { nx, pqfr.."-Qfilter-n-text)",      qp.."ke",         "Qfilter text"..n..sc,     function() ef.filter("text", keep, { input_type = "vimsmart" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-r-text)",      qp.."Ke",         "Qfilter text"..r..sc,     function() ef.filter("text", keep, { input_type = "vimsmart" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-a-text)",      qp.."<C-k>e",     "Qfilter text"..a..sc,     function() ef.filter("text", keep, { input_type = "vimsmart" }, { action = "add", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-n-text)",     qp.."re",         "Qfilter! text"..n..sc,    function() ef.filter("text", nokeep, { input_type = "vimsmart" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-r-text)",     qp.."Re",         "Qfilter! text"..r..sc,    function() ef.filter("text", nokeep, { input_type = "vimsmart" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-a-text)",     qp.."<C-r>e",     "Qfilter! text"..a..sc,    function() ef.filter("text", nokeep, { input_type = "vimsmart" }, { action = "add", is_loclist = false }) end},

    { nx, pqfr.."-Qfilter-n-TEXT)",      qp.."kE",         "Qfilter text"..n..cs,     function() ef.filter("text", keep, { input_type = "sensitive" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-r-TEXT)",      qp.."KE",         "Qfilter text"..r..cs,     function() ef.filter("text", keep, { input_type = "sensitive" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-a-TEXT)",      qp.."<C-k>E",     "Qfilter text"..a..cs,     function() ef.filter("text", keep, { input_type = "sensitive" }, { action = "add", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-n-TEXT)",     qp.."rE",         "Qfilter! text"..n..cs,    function() ef.filter("text", nokeep, { input_type = "sensitive" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-r-TEXT)",     qp.."RE",         "Qfilter! text"..r..cs,    function() ef.filter("text", nokeep, { input_type = "sensitive" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-a-TEXT)",     qp.."<C-r>E",     "Qfilter! text"..a..cs,    function() ef.filter("text", nokeep, { input_type = "sensitive" }, { action = "add", is_loclist = false }) end},

    { nx, pqfr.."-Qfilter-n-textX)",     qp.."k<C-e>",     "Qfilter text"..n..rx,     function() ef.filter("text", keep, { input_type = "regex" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-r-textX)",     qp.."K<C-e>",     "Qfilter text"..r..rx,     function() ef.filter("text", keep, { input_type = "regex" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-a-textX)",     qp.."<C-k><C-e>", "Qfilter text"..a..rx,     function() ef.filter("text", keep, { input_type = "regex" }, { action = "add", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-n-textX)",    qp.."r<C-e>",     "Qfilter! text"..n..rx,    function() ef.filter("text", nokeep, { input_type = "regex" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-r-textX)",    qp.."R<C-e>",     "Qfilter! text"..r..rx,    function() ef.filter("text", nokeep, { input_type = "regex" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-a-textX)",    qp.."<C-r><C-e>", "Qfilter! text"..a..rx,    function() ef.filter("text", nokeep, { input_type = "regex" }, { action = "add", is_loclist = false }) end},

    { nx, pqfr.."-Lfilter-n-text)",      lp.."ke",         "Lfilter text"..n..sc,     function() ef.filter("text", keep, { input_type = "vimsmart" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-r-text)",      lp.."Ke",         "Lfilter text"..r..sc,     function() ef.filter("text", keep, { input_type = "vimsmart" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-a-text)",      lp.."<C-k>e",     "Lfilter text"..a..sc,     function() ef.filter("text", keep, { input_type = "vimsmart" }, { action = "add", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-n-text)",     lp.."re",         "Lfilter! text"..n..sc,    function() ef.filter("text", nokeep, { input_type = "vimsmart" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-r-text)",     lp.."Re",         "Lfilter! text"..r..sc,    function() ef.filter("text", nokeep, { input_type = "vimsmart" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-a-text)",     lp.."<C-r>e",     "Lfilter! text"..a..sc,    function() ef.filter("text", nokeep, { input_type = "vimsmart" }, { action = "add", is_loclist = true }) end},

    { nx, pqfr.."-Lfilter-n-TEXT)",      lp.."kE",         "Lfilter text"..n..cs,     function() ef.filter("text", keep, { input_type = "sensitive" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-r-TEXT)",      lp.."KE",         "Lfilter text"..r..cs,     function() ef.filter("text", keep, { input_type = "sensitive" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-a-TEXT)",      lp.."<C-k>E",     "Lfilter text"..a..cs,     function() ef.filter("text", keep, { input_type = "sensitive" }, { action = "add", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-n-TEXT)",     lp.."rE",         "Lfilter! text"..n..cs,    function() ef.filter("text", nokeep, { input_type = "sensitive" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-r-TEXT)",     lp.."RE",         "Lfilter! text"..r..cs,    function() ef.filter("text", nokeep, { input_type = "sensitive" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-a-TEXT)",     lp.."<C-r>E",     "Lfilter! text"..a..cs,    function() ef.filter("text", nokeep, { input_type = "sensitive" }, { action = "add", is_loclist = true }) end},

    { nx, pqfr.."-Lfilter-n-textX)",     lp.."k<C-e>",     "Lfilter text"..n..rx,     function() ef.filter("text", keep, { input_type = "regex" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-r-textX)",     lp.."K<C-e>",     "Lfilter text"..r..rx,     function() ef.filter("text", keep, { input_type = "regex" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-a-textX)",     lp.."<C-k><C-e>", "Lfilter text"..a..rx,     function() ef.filter("text", keep, { input_type = "regex" }, { action = "add", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-n-textX)",    lp.."r<C-e>",     "Lfilter! text"..n..rx,    function() ef.filter("text", nokeep, { input_type = "regex" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-r-textX)",    lp.."R<C-e>",     "Lfilter! text"..r..rx,    function() ef.filter("text", nokeep, { input_type = "regex" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-a-textX)",    lp.."<C-r><C-e>", "Lfilter! text"..a..rx,    function() ef.filter("text", nokeep, { input_type = "regex" }, { action = "add", is_loclist = true }) end},

    --- Lnum ---

    { nx, pqfr.."-Qfilter-n-lnum)",      qp.."kn",         "Qfilter lnum"..n..sc,     function() ef.filter("lnum", keep, { input_type = "vimsmart" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-r-lnum)",      qp.."Kn",         "Qfilter lnum"..r..sc,     function() ef.filter("lnum", keep, { input_type = "vimsmart" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-a-lnum)",      qp.."<C-k>n",     "Qfilter lnum"..a..sc,     function() ef.filter("lnum", keep, { input_type = "vimsmart" }, { action = "add", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-n-lnum)",     qp.."rn",         "Qfilter! lnum"..n..sc,    function() ef.filter("lnum", nokeep, { input_type = "vimsmart" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-r-lnum)",     qp.."Rn",         "Qfilter! lnum"..r..sc,    function() ef.filter("lnum", nokeep, { input_type = "vimsmart" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-a-lnum)",     qp.."<C-r>n",     "Qfilter! lnum"..a..sc,    function() ef.filter("lnum", nokeep, { input_type = "vimsmart" }, { action = "add", is_loclist = false }) end},

    { nx, pqfr.."-Qfilter-n-LNUM)",      qp.."kN",         "Qfilter lnum"..n..cs,     function() ef.filter("lnum", keep, { input_type = "sensitive" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-r-LNUM)",      qp.."KN",         "Qfilter lnum"..r..cs,     function() ef.filter("lnum", keep, { input_type = "sensitive" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-a-LNUM)",      qp.."<C-k>N",     "Qfilter lnum"..a..cs,     function() ef.filter("lnum", keep, { input_type = "sensitive" }, { action = "add", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-n-LNUM)",     qp.."rN",         "Qfilter! lnum"..n..cs,    function() ef.filter("lnum", nokeep, { input_type = "sensitive" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-r-LNUM)",     qp.."RN",         "Qfilter! lnum"..r..cs,    function() ef.filter("lnum", nokeep, { input_type = "sensitive" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-a-LNUM)",     qp.."<C-r>N",     "Qfilter! lnum"..a..cs,    function() ef.filter("lnum", nokeep, { input_type = "sensitive" }, { action = "add", is_loclist = false }) end},

    { nx, pqfr.."-Qfilter-n-lnumX)",     qp.."k<C-n>",     "Qfilter lnum"..n..rx,     function() ef.filter("lnum", keep, { input_type = "regex" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-r-lnumX)",     qp.."K<C-n>",     "Qfilter lnum"..r..rx,     function() ef.filter("lnum", keep, { input_type = "regex" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-a-lnumX)",     qp.."<C-k><C-n>", "Qfilter lnum"..a..rx,     function() ef.filter("lnum", keep, { input_type = "regex" }, { action = "add", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-n-lnumX)",    qp.."r<C-n>",     "Qfilter! lnum"..n..rx,    function() ef.filter("lnum", nokeep, { input_type = "regex" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-r-lnumX)",    qp.."R<C-n>",     "Qfilter! lnum"..r..rx,    function() ef.filter("lnum", nokeep, { input_type = "regex" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-a-lnumX)",    qp.."<C-r><C-n>", "Qfilter! lnum"..a..rx,    function() ef.filter("lnum", nokeep, { input_type = "regex" }, { action = "add", is_loclist = false }) end},

    { nx, pqfr.."-Lfilter-n-lnum)",      lp.."kn",         "Lfilter lnum"..n..sc,     function() ef.filter("lnum", keep, { input_type = "vimsmart" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-r-lnum)",      lp.."Kn",         "Lfilter lnum"..r..sc,     function() ef.filter("lnum", keep, { input_type = "vimsmart" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-a-lnum)",      lp.."<C-k>n",     "Lfilter lnum"..a..sc,     function() ef.filter("lnum", keep, { input_type = "vimsmart" }, { action = "add", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-n-lnum)",     lp.."rn",         "Lfilter! lnum"..n..sc,    function() ef.filter("lnum", nokeep, { input_type = "vimsmart" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-r-lnum)",     lp.."Rn",         "Lfilter! lnum"..r..sc,    function() ef.filter("lnum", nokeep, { input_type = "vimsmart" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-a-lnum)",     lp.."<C-r>n",     "Lfilter! lnum"..a..sc,    function() ef.filter("lnum", nokeep, { input_type = "vimsmart" }, { action = "add", is_loclist = true }) end},

    { nx, pqfr.."-Lfilter-n-LNUM)",      lp.."kN",         "Lfilter lnum"..n..cs,     function() ef.filter("lnum", keep, { input_type = "sensitive" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-r-LNUM)",      lp.."KN",         "Lfilter lnum"..r..cs,     function() ef.filter("lnum", keep, { input_type = "sensitive" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-a-LNUM)",      lp.."<C-k>N",     "Lfilter lnum"..a..cs,     function() ef.filter("lnum", keep, { input_type = "sensitive" }, { action = "add", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-n-LNUM)",     lp.."rN",         "Lfilter! lnum"..n..cs,    function() ef.filter("lnum", nokeep, { input_type = "sensitive" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-r-LNUM)",     lp.."RN",         "Lfilter! lnum"..r..cs,    function() ef.filter("lnum", nokeep, { input_type = "sensitive" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-a-LNUM)",     lp.."<C-r>N",     "Lfilter! lnum"..a..cs,    function() ef.filter("lnum", nokeep, { input_type = "sensitive" }, { action = "add", is_loclist = true }) end},

    { nx, pqfr.."-Lfilter-n-lnumX)",     lp.."k<C-n>",     "Lfilter lnum"..n..rx,     function() ef.filter("lnum", keep, { input_type = "regex" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-r-lnumX)",     lp.."K<C-n>",     "Lfilter lnum"..r..rx,     function() ef.filter("lnum", keep, { input_type = "regex" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-a-lnumX)",     lp.."<C-k><C-n>", "Lfilter lnum"..a..rx,     function() ef.filter("lnum", keep, { input_type = "regex" }, { action = "add", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-n-lnumX)",    lp.."r<C-n>",     "Lfilter! lnum"..n..rx,    function() ef.filter("lnum", nokeep, { input_type = "regex" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-r-lnumX)",    lp.."R<C-n>",     "Lfilter! lnum"..r..rx,    function() ef.filter("lnum", nokeep, { input_type = "regex" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-a-lnumX)",    lp.."<C-r><C-n>", "Lfilter! lnum"..a..rx,    function() ef.filter("lnum", nokeep, { input_type = "regex" }, { action = "add", is_loclist = true }) end},

    --- Type ---

    { nx, pqfr.."-Qfilter-n-type)",      qp.."kt",         "Qfilter type"..n..sc,     function() ef.filter("type", keep, { input_type = "vimsmart" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-r-type)",      qp.."Kt",         "Qfilter type"..r..sc,     function() ef.filter("type", keep, { input_type = "vimsmart" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-a-type)",      qp.."<C-k>t",     "Qfilter type"..a..sc,     function() ef.filter("type", keep, { input_type = "vimsmart" }, { action = "add", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-n-type)",     qp.."rt",         "Qfilter! type"..n..sc,    function() ef.filter("type", nokeep, { input_type = "vimsmart" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-r-type)",     qp.."Rt",         "Qfilter! type"..r..sc,    function() ef.filter("type", nokeep, { input_type = "vimsmart" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-a-type)",     qp.."<C-r>t",     "Qfilter! type"..a..sc,    function() ef.filter("type", nokeep, { input_type = "vimsmart" }, { action = "add", is_loclist = false }) end},

    { nx, pqfr.."-Qfilter-n-TYPE)",      qp.."kT",         "Qfilter type"..n..cs,     function() ef.filter("type", keep, { input_type = "sensitive" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-r-TYPE)",      qp.."KT",         "Qfilter type"..r..cs,     function() ef.filter("type", keep, { input_type = "sensitive" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-a-TYPE)",      qp.."<C-k>T",     "Qfilter type"..a..cs,     function() ef.filter("type", keep, { input_type = "sensitive" }, { action = "add", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-n-TYPE)",     qp.."rT",         "Qfilter! type"..n..cs,    function() ef.filter("type", nokeep, { input_type = "sensitive" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-r-TYPE)",     qp.."RT",         "Qfilter! type"..r..cs,    function() ef.filter("type", nokeep, { input_type = "sensitive" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-a-TYPE)",     qp.."<C-r>T",     "Qfilter! type"..a..cs,    function() ef.filter("type", nokeep, { input_type = "sensitive" }, { action = "add", is_loclist = false }) end},

    { nx, pqfr.."-Qfilter-n-typeX)",     qp.."k<C-t>",     "Qfilter type"..n..rx,     function() ef.filter("type", keep, { input_type = "regex" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-r-typeX)",     qp.."K<C-t>",     "Qfilter type"..r..rx,     function() ef.filter("type", keep, { input_type = "regex" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-a-typeX)",     qp.."<C-k><C-t>", "Qfilter type"..a..rx,     function() ef.filter("type", keep, { input_type = "regex" }, { action = "add", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-n-typeX)",    qp.."r<C-t>",     "Qfilter! type"..n..rx,    function() ef.filter("type", nokeep, { input_type = "regex" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-r-typeX)",    qp.."R<C-t>",     "Qfilter! type"..r..rx,    function() ef.filter("type", nokeep, { input_type = "regex" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-a-typeX)",    qp.."<C-r><C-t>", "Qfilter! type"..a..rx,    function() ef.filter("type", nokeep, { input_type = "regex" }, { action = "add", is_loclist = false }) end},

    { nx, pqfr.."-Lfilter-n-type)",      lp.."kt",         "Lfilter type"..n..sc,     function() ef.filter("type", keep, { input_type = "vimsmart" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-r-type)",      lp.."Kt",         "Lfilter type"..r..sc,     function() ef.filter("type", keep, { input_type = "vimsmart" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-a-type)",      lp.."<C-k>t",     "Lfilter type"..a..sc,     function() ef.filter("type", keep, { input_type = "vimsmart" }, { action = "add", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-n-type)",     lp.."rt",         "Lfilter! type"..n..sc,    function() ef.filter("type", nokeep, { input_type = "vimsmart" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-r-type)",     lp.."Rt",         "Lfilter! type"..r..sc,    function() ef.filter("type", nokeep, { input_type = "vimsmart" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-a-type)",     lp.."<C-r>t",     "Lfilter! type"..a..sc,    function() ef.filter("type", nokeep, { input_type = "vimsmart" }, { action = "add", is_loclist = true }) end},

    { nx, pqfr.."-Lfilter-n-TYPE)",      lp.."kT",         "Lfilter type"..n..cs,     function() ef.filter("type", keep, { input_type = "sensitive" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-r-TYPE)",      lp.."KT",         "Lfilter type"..r..cs,     function() ef.filter("type", keep, { input_type = "sensitive" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-a-TYPE)",      lp.."<C-k>T",     "Lfilter type"..a..cs,     function() ef.filter("type", keep, { input_type = "sensitive" }, { action = "add", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-n-TYPE)",     lp.."rT",         "Lfilter! type"..n..cs,    function() ef.filter("type", nokeep, { input_type = "sensitive" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-r-TYPE)",     lp.."RT",         "Lfilter! type"..r..cs,    function() ef.filter("type", nokeep, { input_type = "sensitive" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-a-TYPE)",     lp.."<C-r>T",     "Lfilter! type"..a..cs,    function() ef.filter("type", nokeep, { input_type = "sensitive" }, { action = "add", is_loclist = true }) end},

    { nx, pqfr.."-Lfilter-n-typeX)",     lp.."k<C-t>",     "Lfilter type"..n..rx,     function() ef.filter("type", keep, { input_type = "regex" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-r-typeX)",     lp.."K<C-t>",     "Lfilter type"..r..rx,     function() ef.filter("type", keep, { input_type = "regex" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-a-typeX)",     lp.."<C-k><C-t>", "Lfilter type"..a..rx,     function() ef.filter("type", keep, { input_type = "regex" }, { action = "add", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-n-typeX)",    lp.."r<C-t>",     "Lfilter! type"..n..rx,    function() ef.filter("type", nokeep, { input_type = "regex" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-r-typeX)",    lp.."R<C-t>",     "Lfilter! type"..r..rx,    function() ef.filter("type", nokeep, { input_type = "regex" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-a-typeX)",    lp.."<C-r><C-t>", "Lfilter! type"..a..rx,    function() ef.filter("type", nokeep, { input_type = "regex" }, { action = "add", is_loclist = true }) end},

    ------------
    --- GREP ---
    ------------

    { nx, "<nop>", "<leader>qg",     "Avoid falling back to defaults", nil },
    { nx, "<nop>", "<leader>qG",     "Avoid falling back to defaults", nil },
    { nx, "<nop>", "<leader>q<c-g>", "Avoid falling back to defaults", nil },
    { nx, "<nop>", "<leader>lg",     "Avoid falling back to defaults", nil },
    { nx, "<nop>", "<leader>lG",     "Avoid falling back to defaults", nil },
    { nx, "<nop>", "<leader>l<c-g>", "Avoid falling back to defaults", nil },

    -- TODO: Might be able to move the prefixes back to char literals, but wait until Grep API is final
    { nx, pqfr.."-grep-n-cwd)",    qp.."gd",         "Qgrep cwd, new"..sc,           function() eg.grep("cwd", sys_async, in_vimsmart, qflist_new) end },
    { nx, pqfr.."-grep-r-cwd)",    qp.."Gd",         "Qgrep cwd, replace"..sc,       function() eg.grep("cwd", sys_async, in_vimsmart, qflist_replace) end },
    { nx, pqfr.."-grep-a-cwd)",    qp.."<C-g>d",     "Qgrep cwd, add"..sc,           function() eg.grep("cwd", sys_async, in_vimsmart, qflist_add) end },
    { nx, pqfr.."-grep-n-CWD)",    qp.."gD",         "Qgrep cwd, new"..cs,           function() eg.grep("cwd", sys_async, in_sensitive, qflist_new) end },
    { nx, pqfr.."-grep-r-CWD)",    qp.."GD",         "Qgrep cwd, replace"..cs,       function() eg.grep("cwd", sys_async, in_sensitive, qflist_replace) end },
    { nx, pqfr.."-grep-a-CWD)",    qp.."<C-g>D",     "Qgrep cwd, add"..cs,           function() eg.grep("cwd", sys_async, in_sensitive, qflist_add) end },
    { nx, pqfr.."-grep-n-cwdX)",   qp.."g<C-d>",     "Qgrep cwd, new"..rx,           function() eg.grep("cwd", sys_async, in_regex, qflist_new) end },
    { nx, pqfr.."-grep-r-cwdX)",   qp.."G<C-d>",     "Qgrep cwd, replace"..rx,       function() eg.grep("cwd", sys_async, in_regex, qflist_replace) end },
    { nx, pqfr.."-grep-a-cwdX)",   qp.."<C-g><C-d>", "Qgrep cwd, add"..rx,           function() eg.grep("cwd", sys_async, in_regex, qflist_add) end },

    { nx, pqfr.."-lgrep-n-cwd)",   lp.."gd",         "Lgrep cwd, new"..sc,           function() eg.grep("cwd", sys_async, in_vimsmart, llist_new) end },
    { nx, pqfr.."-lgrep-r-cwd)",   lp.."Gd",         "Lgrep cwd, replace"..sc,       function() eg.grep("cwd", sys_async, in_vimsmart, llist_replace) end },
    { nx, pqfr.."-lgrep-a-cwd)",   lp.."<C-g>d",     "Lgrep cwd, add"..sc,           function() eg.grep("cwd", sys_async, in_vimsmart, llist_add) end },
    { nx, pqfr.."-lgrep-n-CWD)",   lp.."gD",         "Lgrep cwd, new"..cs,           function() eg.grep("cwd", sys_async, in_sensitive, llist_new) end },
    { nx, pqfr.."-lgrep-r-CWD)",   lp.."GD",         "Lgrep cwd, replace"..cs,       function() eg.grep("cwd", sys_async, in_sensitive, llist_replace) end },
    { nx, pqfr.."-lgrep-a-CWD)",   lp.."<C-g>D",     "Lgrep cwd, add"..cs,           function() eg.grep("cwd", sys_async, in_sensitive, llist_add) end },
    { nx, pqfr.."-lgrep-n-cwdX)",  lp.."g<C-d>",     "Lgrep cwd, new"..rx,           function() eg.grep("cwd", sys_async, in_regex, llist_new) end },
    { nx, pqfr.."-lgrep-r-cwdX)",  lp.."G<C-d>",     "Lgrep cwd, replace"..rx,       function() eg.grep("cwd", sys_async, in_regex, llist_replace) end },
    { nx, pqfr.."-lgrep-a-cwdX)",  lp.."<C-g><C-d>", "Lgrep cwd, add"..rx,           function() eg.grep("cwd", sys_async, in_regex, llist_add) end },

    { nx, pqfr.."-grep-n-help)",   qp.."gh",         "Qgrep docs, new"..sc,          function() eg.grep("help", sys_async, in_vimsmart, sys_help_new) end },
    { nx, pqfr.."-grep-r-help)",   qp.."Gh",         "Qgrep docs, replace"..sc,      function() eg.grep("help", sys_async, in_vimsmart, sys_help_replace) end },
    { nx, pqfr.."-grep-a-help)",   qp.."<C-g>h",     "Qgrep docs, add"..sc,          function() eg.grep("help", sys_async, in_vimsmart, sys_help_add) end },
    { nx, pqfr.."-grep-n-HELP)",   qp.."gH",         "Qgrep docs, new"..cs,          function() eg.grep("help", sys_async, in_sensitive, sys_help_new) end },
    { nx, pqfr.."-grep-r-HELP)",   qp.."GH",         "Qgrep docs, replace"..cs,      function() eg.grep("help", sys_async, in_sensitive, sys_help_replace) end },
    { nx, pqfr.."-grep-a-HELP)",   qp.."<C-g>H",     "Qgrep docs, add"..cs,          function() eg.grep("help", sys_async, in_sensitive, sys_help_add) end },
    { nx, pqfr.."-grep-n-helpX)",  qp.."g<C-h>",     "Qgrep docs, new"..rx,          function() eg.grep("help", sys_async, in_regex, sys_help_new) end },
    { nx, pqfr.."-grep-r-helpX)",  qp.."G<C-h>",     "Qgrep docs, replace"..rx,      function() eg.grep("help", sys_async, in_regex, sys_help_replace) end },
    { nx, pqfr.."-grep-a-helpX)",  qp.."<C-g><C-h>", "Qgrep docs, add"..rx,          function() eg.grep("help", sys_async, in_regex, sys_help_add) end },

    { nx, pqfr.."-lgrep-n-help)",  lp.."gh",         "Lgrep docs, new"..sc,          function() eg.grep("help", sys_async, in_vimsmart, sys_help_lnew) end },
    { nx, pqfr.."-lgrep-r-help)",  lp.."Gh",         "Lgrep docs, replace"..sc,      function() eg.grep("help", sys_async, in_vimsmart, sys_help_lreplace) end },
    { nx, pqfr.."-lgrep-a-help)",  lp.."<C-g>h",     "Lgrep docs, add"..sc,          function() eg.grep("help", sys_async, in_vimsmart, sys_help_ladd) end },
    { nx, pqfr.."-lgrep-n-HELP)",  lp.."gH",         "Lgrep docs, new"..cs,          function() eg.grep("help", sys_async, in_sensitive, sys_help_lnew) end },
    { nx, pqfr.."-lgrep-r-HELP)",  lp.."GH",         "Lgrep docs, replace"..cs,      function() eg.grep("help", sys_async, in_sensitive, sys_help_lreplace) end },
    { nx, pqfr.."-lgrep-a-HELP)",  lp.."<C-g>H",     "Lgrep docs, add"..cs,          function() eg.grep("help", sys_async, in_sensitive, sys_help_ladd) end },
    { nx, pqfr.."-lgrep-n-helpX)", lp.."g<C-h>",     "Lgrep docs, new"..rx,          function() eg.grep("help", sys_async, in_regex, sys_help_lnew) end },
    { nx, pqfr.."-lgrep-r-helpX)", lp.."G<C-h>",     "Lgrep docs, replace"..rx,      function() eg.grep("help", sys_async, in_regex, sys_help_lreplace) end },
    { nx, pqfr.."-lgrep-a-helpX)", lp.."<C-g><C-h>", "Lgrep docs, add"..rx,          function() eg.grep("help", sys_async, in_vimsmart, sys_help_ladd) end },

    { nx, pqfr.."-grep-n-bufs)",   qp.."gu",         "Qgrep open bufs, new"..sc,     function() eg.grep("bufs", sys_async, in_vimsmart, qflist_new) end },
    { nx, pqfr.."-grep-r-bufs)",   qp.."Gu",         "Qgrep open bufs, replace"..sc, function() eg.grep("bufs", sys_async, in_vimsmart, qflist_replace) end },
    { nx, pqfr.."-grep-a-bufs)",   qp.."<C-g>u",     "Qgrep open bufs, add"..sc,     function() eg.grep("bufs", sys_async, in_vimsmart, qflist_add) end },
    { nx, pqfr.."-grep-n-BUFS)",   qp.."gU",         "Qgrep open bufs, new"..cs,     function() eg.grep("bufs", sys_async, in_sensitive, qflist_new) end },
    { nx, pqfr.."-grep-r-BUFS)",   qp.."GU",         "Qgrep open bufs, replace"..cs, function() eg.grep("bufs", sys_async, in_sensitive, qflist_replace) end },
    { nx, pqfr.."-grep-a-BUFS)",   qp.."<C-g>U",     "Qgrep open bufs, add"..cs,     function() eg.grep("bufs", sys_async, in_sensitive, qflist_add) end },
    { nx, pqfr.."-grep-n-bufsX)",  qp.."g<C-u>",     "Qgrep open bufs, new"..rx,     function() eg.grep("bufs", sys_async, in_regex, qflist_new) end },
    { nx, pqfr.."-grep-r-bufsX)",  qp.."G<C-u>",     "Qgrep open bufs, replace"..rx, function() eg.grep("bufs", sys_async, in_regex, qflist_replace) end },
    { nx, pqfr.."-grep-a-bufsX)",  qp.."<C-g><C-u>", "Qgrep open bufs, add"..rx,     function() eg.grep("bufs", sys_async, in_regex, qflist_add) end },

    { nx, pqfr.."-lgrep-n-cbuf)",  lp.."gu",         "Lgrep cur buf, new"..sc,       function() eg.grep("cbuf", sys_async, in_vimsmart, llist_new) end },
    { nx, pqfr.."-lgrep-r-cbuf)",  lp.."Gu",         "Lgrep cur buf, replace"..sc,   function() eg.grep("cbuf", sys_async, in_vimsmart, llist_replace) end },
    { nx, pqfr.."-lgrep-a-cbuf)",  lp.."<C-g>u",     "Lgrep cur buf, add"..sc,       function() eg.grep("cbuf", sys_async, in_vimsmart, llist_add) end },
    { nx, pqfr.."-lgrep-n-CBUF)",  lp.."gU",         "Lgrep cur buf, new"..cs,       function() eg.grep("cbuf", sys_async, in_sensitive, llist_new) end },
    { nx, pqfr.."-lgrep-r-CBUF)",  lp.."GU",         "Lgrep cur buf, replace"..cs,   function() eg.grep("cbuf", sys_async, in_sensitive, llist_replace) end },
    { nx, pqfr.."-lgrep-a-CBUF)",  lp.."<C-g>U",     "Lgrep cur buf, add"..cs,       function() eg.grep("cbuf", sys_async, in_sensitive, llist_add) end },
    { nx, pqfr.."-lgrep-n-cbufX)", lp.."g<C-u>",     "Lgrep cur buf, new"..rx,       function() eg.grep("cbuf", sys_async, in_regex, llist_new) end },
    { nx, pqfr.."-lgrep-r-cbufX)", lp.."G<C-u>",     "Lgrep cur buf, replace"..rx,   function() eg.grep("cbuf", sys_async, in_regex, llist_replace) end },
    { nx, pqfr.."-lgrep-a-cbufX)", lp.."<C-g><C-u>", "Lgrep cur buf, add"..rx,       function() eg.grep("cbuf", sys_async, in_regex, llist_add) end },

    -------------------------
    --- OPEN/CLOSE/RESIZE ---
    -------------------------

    { nn, pqfr.."-open-qf-list)",   qp.."p", "Open the quickfix list",   function() eo._open_qflist({ always_resize = true, height = vim.v.count }) end },
    { nn, pqfr.."-close-qf-list)",  qp.."o", "Close the quickfix list",  function() eo._close_qflist() end },
    { nn, pqfr.."-toggle-qf-list)", qp.."q", "Toggle the quickfix list", function() eo._toggle_qflist()  end },
    { nn, pqfr.."-open-loclist)",   lp.."p", "Open the location list",   function() eo._open_loclist({ always_resize = true, height = vim.v.count }) end },
    { nn, pqfr.."-close-loclist)",  lp.."o", "Close the location list",  function() eo._close_loclist() end },
    { nn, pqfr.."-toggle-loclist)", lp.."l", "Toggle the location list", function() eo._toggle_loclist() end },

    ------------------
    --- NAVIGATION ---
    ------------------

    { nn, pqfr.."-qf-prev)",  "[q",          "Go to a previous qf entry",       function() en.q_prev(vim.v.count1) end },
    { nn, pqfr.."-qf-next)",  "]q",          "Go to a later qf entry",          function() en.q_next(vim.v.count1) end },
    { nn, pqfr.."-qf-pfile)", "[<C-q>",      "Go to the previous qf file",      function() en.q_pfile(vim.v.count1) end },
    { nn, pqfr.."-qf-nfile)", "]<C-q>",      "Go to the next qf file",          function() en.q_nfile(vim.v.count1) end },
    { nn, pqfr.."-qf-jump)",  qp .."<C-q>",  "Jump to the qflist",              function() en.q_jump(vim.v.count) end },
    { nn, pqfr.."-ll-prev)",  "[l",          "Go to a previous loclist entry",  function() en.l_prev(vim.v.count1) end },
    { nn, pqfr.."-ll-next)",  "]l",          "Go to a later loclist entry",     function() en.l_next(vim.v.count1) end },
    { nn, pqfr.."-ll-pfile)", "[<C-l>",      "Go to the previous loclist file", function() en.l_pfile(vim.v.count1) end },
    { nn, pqfr.."-ll-nfile)", "]<C-l>",      "Go to the next loclist file",     function() en.l_nfile(vim.v.count1) end },
    { nn, pqfr.."-ll-jump)",  lp .. "<C-l>", "Jump to the loclist",             function() en.l_jump(vim.v.count) end },

    ------------
    --- SORT ---
    ------------

    { nn, "<nop>", "<leader>qt",     "Avoid falling back to defaults", nil },
    { nn, "<nop>", "<leader>qT",     "Avoid falling back to defaults", nil },
    { nn, "<nop>", "<leader>q<C-t>", "Avoid falling back to defaults", nil },
    { nn, "<nop>", "<leader>lt",     "Avoid falling back to defaults", nil },
    { nn, "<nop>", "<leader>lT",     "Avoid falling back to defaults", nil },
    { nn, "<nop>", "<leader>l<C-t>", "Avoid falling back to defaults", nil },

    { nn, pqfr.."-qsort-n-fname-asc)",       qp.."tf",  "Qsort by fname asc"..n,           function() et.sort("fname", { dir = "asc" }, { action = "new", is_loclist = false }) end },
    { nn, pqfr.."-qsort-n-fname-desc)",      qp.."tF",  "Qsort by fname desc"..n,          function() et.sort("fname", { dir = "desc" }, { action = "new", is_loclist = false }) end },
    { nn, pqfr.."-qsort-n-fname-diag-asc)",  qp.."tif", "Qsort by fname_diag asc"..n,      function() et.sort("fname_diag", { dir = "asc" }, { action = "new", is_loclist = false }) end },
    { nn, pqfr.."-qsort-n-fname-diag-desc)", qp.."tiF", "Qsort by fname_diag desc"..n,     function() et.sort("fname_diag", { dir = "desc" }, { action = "new", is_loclist = false }) end },
    { nn, pqfr.."-qsort-n-severity-asc)",    qp.."tis", "Qsort by severity asc"..n,        function() et.sort("severity", { dir = "asc" }, { action = "new", is_loclist = false }) end },
    { nn, pqfr.."-qsort-n-severity-desc)",   qp.."tiS", "Qsort by severity desc"..n,       function() et.sort("severity", { dir = "desc" }, { action = "new", is_loclist = false }) end },
    { nn, pqfr.."-qsort-n-type-asc)",        qp.."tt",  "Qsort by type asc"..n,            function() et.sort("type", { dir = "asc" }, { action = "new", is_loclist = false }) end },
    { nn, pqfr.."-qsort-n-type-desc)",       qp.."tT",  "Qsort by type desc"..n,           function() et.sort("type", { dir = "desc" }, { action = "new", is_loclist = false }) end },

    { nn, pqfr.."-qsort-r-fname-asc)",       qp.."Tf",  "Qsort by fname asc"..r,           function() et.sort("fname", { dir = "asc" }, { action = "replace", is_loclist = false }) end },
    { nn, pqfr.."-qsort-r-fname-desc)",      qp.."TF",  "Qsort by fname desc"..r,          function() et.sort("fname", { dir = "desc" }, { action = "replace", is_loclist = false }) end },
    { nn, pqfr.."-qsort-r-fname-diag-asc)",  qp.."Tif", "Qsort by fname_diag asc"..r,      function() et.sort("fname_diag", { dir = "asc" }, { action = "replace", is_loclist = false }) end },
    { nn, pqfr.."-qsort-r-fname-diag-desc)", qp.."TiF", "Qsort by fname_diag desc"..r,     function() et.sort("fname_diag", { dir = "desc" }, { action = "replace", is_loclist = false }) end },
    { nn, pqfr.."-qsort-r-severity-asc)",    qp.."Tis", "Qsort by severity asc"..r,        function() et.sort("severity", { dir = "asc" }, { action = "replace", is_loclist = false }) end },
    { nn, pqfr.."-qsort-r-severity-desc)",   qp.."TiS", "Qsort by severity desc"..r,       function() et.sort("severity", { dir = "desc" }, { action = "replace", is_loclist = false }) end },
    { nn, pqfr.."-qsort-r-type-asc)",        qp.."Tt",  "Qsort by type asc"..r,            function() et.sort("type", { dir = "asc" }, { action = "replace", is_loclist = false }) end },
    { nn, pqfr.."-qsort-r-type-desc)",       qp.."TT",  "Qsort by type desc"..r,           function() et.sort("type", { dir = "desc" }, { action = "replace", is_loclist = false }) end },

    { nn, pqfr.."-qsort-a-fname-asc)",       qp.."<C-t>f",  "Qsort by fname asc"..a,       function() et.sort("fname", { dir = "asc" }, { action = "add", is_loclist = false }) end },
    { nn, pqfr.."-qsort-a-fname-desc)",      qp.."<C-t>F",  "Qsort by fname desc"..a,      function() et.sort("fname", { dir = "desc" }, { action = "add", is_loclist = false }) end },
    { nn, pqfr.."-qsort-a-fname-diag-asc)",  qp.."<C-t>if", "Qsort by fname_diag asc"..a,  function() et.sort("fname_diag", { dir = "asc" }, { action = "add", is_loclist = false }) end },
    { nn, pqfr.."-qsort-a-fname-diag-desc)", qp.."<C-t>iF", "Qsort by fname_diag desc"..a, function() et.sort("fname_diag", { dir = "desc" }, { action = "add", is_loclist = false }) end },
    { nn, pqfr.."-qsort-a-severity-asc)",    qp.."<C-t>is", "Qsort by severity asc"..a,    function() et.sort("severity", { dir = "asc" }, { action = "add", is_loclist = false }) end },
    { nn, pqfr.."-qsort-a-severity-desc)",   qp.."<C-t>iS", "Qsort by severity desc"..a,   function() et.sort("severity", { dir = "desc" }, { action = "add", is_loclist = false }) end },
    { nn, pqfr.."-qsort-a-type-asc)",        qp.."<C-t>t",  "Qsort by type asc"..a,        function() et.sort("type", { dir = "asc" }, { action = "add", is_loclist = false }) end },
    { nn, pqfr.."-qsort-a-type-desc)",       qp.."<C-t>T",  "Qsort by type desc"..a,       function() et.sort("type", { dir = "desc" }, { action = "add", is_loclist = false }) end },

    { nn, pqfr.."-lsort-n-fname-asc)",       lp.."tf",  "Lsort by fname asc"..n,           function() et.sort("fname", { dir = "asc" }, { action = "new", is_loclist = true }) end },
    { nn, pqfr.."-lsort-n-fname-desc)",      lp.."tF",  "Lsort by fname desc"..n,          function() et.sort("fname", { dir = "desc" }, { action = "new", is_loclist = true }) end },
    { nn, pqfr.."-lsort-n-fname-diag-asc)",  lp.."tif", "Lsort by fname_diag asc"..n,      function() et.sort("fname_diag", { dir = "asc" }, { action = "new", is_loclist = true }) end },
    { nn, pqfr.."-lsort-n-fname-diag-desc)", lp.."tiF", "Lsort by fname_diag desc"..n,     function() et.sort("fname_diag", { dir = "desc" }, { action = "new", is_loclist = true }) end },
    { nn, pqfr.."-lsort-n-severity-asc)",    lp.."tis", "Lsort by severity asc"..n,        function() et.sort("severity", { dir = "asc" }, { action = "new", is_loclist = true }) end },
    { nn, pqfr.."-lsort-n-severity-desc)",   lp.."tiS", "Lsort by severity desc"..n,       function() et.sort("severity", { dir = "desc" }, { action = "new", is_loclist = true }) end },
    { nn, pqfr.."-lsort-n-type-asc)",        lp.."tt",  "Lsort by type asc"..n,            function() et.sort("type", { dir = "asc" }, { action = "new", is_loclist = true }) end },
    { nn, pqfr.."-lsort-n-type-desc)",       lp.."tT",  "Lsort by type desc"..n,           function() et.sort("type", { dir = "desc" }, { action = "new", is_loclist = true }) end },

    { nn, pqfr.."-lsort-r-fname-asc)",       lp.."Tf",  "Lsort by fname asc"..r,           function() et.sort("fname", { dir = "asc" }, { action = "replace", is_loclist = true }) end },
    { nn, pqfr.."-lsort-r-fname-desc)",      lp.."TF",  "Lsort by fname desc"..r,          function() et.sort("fname", { dir = "desc" }, { action = "replace", is_loclist = true }) end },
    { nn, pqfr.."-lsort-r-fname-diag-asc)",  lp.."Tif", "Lsort by fname_diag asc"..r,      function() et.sort("fname_diag", { dir = "asc" }, { action = "replace", is_loclist = true }) end },
    { nn, pqfr.."-lsort-r-fname-diag-desc)", lp.."TiF", "Lsort by fname_diag desc"..r,     function() et.sort("fname_diag", { dir = "desc" }, { action = "replace", is_loclist = true }) end },
    { nn, pqfr.."-lsort-r-severity-asc)",    lp.."Tis", "Lsort by severity asc"..r,        function() et.sort("severity", { dir = "asc" }, { action = "replace", is_loclist = true }) end },
    { nn, pqfr.."-lsort-r-severity-desc)",   lp.."TiS", "Lsort by severity desc"..r,       function() et.sort("severity", { dir = "desc" }, { action = "replace", is_loclist = true }) end },
    { nn, pqfr.."-lsort-r-type-asc)",        lp.."Tt",  "Lsort by type asc"..r,            function() et.sort("type", { dir = "asc" }, { action = "replace", is_loclist = true }) end },
    { nn, pqfr.."-lsort-r-type-desc)",       lp.."TT",  "Lsort by type desc"..r,           function() et.sort("type", { dir = "desc" }, { action = "replace", is_loclist = true }) end },

    { nn, pqfr.."-lsort-a-fname-asc)",       lp.."<C-t>f",  "Lsort by fname asc"..a,       function() et.sort("fname", { dir = "asc" }, { action = "add", is_loclist = true }) end },
    { nn, pqfr.."-lsort-a-fname-desc)",      lp.."<C-t>F",  "Lsort by fname desc"..a,      function() et.sort("fname", { dir = "desc" }, { action = "add", is_loclist = true }) end },
    { nn, pqfr.."-lsort-a-fname-diag-asc)",  lp.."<C-t>if", "Lsort by fname_diag asc"..a,  function() et.sort("fname_diag", { dir = "asc" }, { action = "add", is_loclist = true }) end },
    { nn, pqfr.."-lsort-a-fname-diag-desc)", lp.."<C-t>iF", "Lsort by fname_diag desc"..a, function() et.sort("fname_diag", { dir = "desc" }, { action = "add", is_loclist = true }) end },
    { nn, pqfr.."-lsort-a-severity-asc)",    lp.."<C-t>is", "Lsort by severity asc"..a,    function() et.sort("severity", { dir = "asc" }, { action = "add", is_loclist = true }) end },
    { nn, pqfr.."-lsort-a-severity-desc)",   lp.."<C-t>iS", "Lsort by severity desc"..a,   function() et.sort("severity", { dir = "desc" }, { action = "add", is_loclist = true }) end },
    { nn, pqfr.."-lsort-a-type-asc)",        lp.."<C-t>t",  "Lsort by type asc"..a,        function() et.sort("type", { dir = "asc" }, { action = "add", is_loclist = true }) end },
    { nn, pqfr.."-lsort-a-type-desc)",       lp.."<C-t>T",  "Lsort by type desc"..a,       function() et.sort("type", { dir = "desc" }, { action = "add", is_loclist = true }) end },

    -------------
    --- STACK ---
    -------------

    { nn, pqfr.."-qf-older)",   qp.."[", "Go to an older qflist",                    function() es.q_older(vim.v.count1) end },
    { nn, pqfr.."-qf-newer)",   qp.."]", "Go to a newer qflist",                     function() es.q_newer(vim.v.count1) end },
    { nn, pqfr.."-qf-history)", qp.."Q", "View or jump within the quickfix history", function() es.q_history(vim.v.count) end },
    { nn, pqfr.."-qf-del)",     qp.."e", "Delete a list from the quickfix stack",    function() es.q_del(vim.v.count) end },
    { nn, pqfr.."-qf-del-all)", qp.."E", "Delete all items from the quickfix stack", function() es.q_del_all() end },
    { nn, pqfr.."-ll-older)",   lp.."[", "Go to an older location list",             function() es.l_older(vim.v.count1) end },
    { nn, pqfr.."-ll-newer)",   lp.."]", "Go to a newer location list",              function() es.l_newer(vim.v.count1) end },
    { nn, pqfr.."-ll-history)", lp.."L", "View or jump within the loclist history",  function() es.l_history(vim.v.count) end },
    { nn, pqfr.."-ll-del)",     lp.."e", "Delete a list from the loclist stack",     function() es.l_del(vim.v.count) end },
    { nn, pqfr.."-ll-del-all)", lp.."E", "Delete all items from the loclist stack",  function() es.l_del_all() end },
}

for _, map in ipairs(rancher_keymaps) do
    for _, mode in ipairs(map[1]) do
        vim.api.nvim_set_keymap(mode, map[2], "", {
            callback = map[5],
            desc = map[4],
            noremap = true,
        })
    end
end

if vim.g.qf_rancher_set_default_maps then
    for _, map in ipairs(rancher_keymaps) do
        for _, mode in ipairs(map[1]) do
            vim.api.nvim_set_keymap(mode, map[3], map[2], {
                desc = map[4],
                noremap = true,
            })
        end
    end

    -- vim.keym.del("n", "<nop>")
end

----------------
--- GREP CMD ---
----------------

local function find_matches(cargs, matches)
    cargs.fargs = cargs.fargs or {}
    for _, arg in ipairs(cargs.fargs) do
        if matches[arg] then
            return matches[arg]
        end
    end

    return matches.default
end

if vim.g.qf_rancher_set_default_cmds then
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

if vim.g.qf_rancher_set_default_cmds then
    local function check_arg(fargs, valid_args, default)
        for _, arg in ipairs(fargs) do
            if vim.tbl_contains(valid_args, arg) then
                return arg
            end
        end

        return default
    end

    local function find_pattern(fargs)
        for _, arg in ipairs(fargs) do
            if vim.startswith(arg, "/") then
                return arg
            end
        end

        return nil
    end

    --------------
    --- FILTER ---
    --------------

    --- @param cargs vim.api.keyset.create_user_command.command_args
    --- @param is_loclist boolean
    --- @return nil
    local function filter_cmd(cargs, is_loclist)
        cargs = cargs or {}
        local fargs = cargs.fargs

        local filters = ef.get_filter_names()
        assert(#filters > 1, "No filter functions available")
        local filter_func = check_arg(fargs, filters, "cfilter")

        local keep_this = not cargs.bang
        local action = check_arg(fargs, actions, default_action)
        local pattern = find_pattern(fargs)
        local count = cargs.count > 0 and cargs.count or nil

        local filter_opts = { keep = keep_this }
        -- TODO: is this right the right way to handle input type?
        local input_opts = { input_type = pattern and "regex" or "vimsmart", pattern = pattern }
        local output_opts = { is_loclist = is_loclist, action = action, count = count }

        ef.filter(filter_func, filter_opts, input_opts, output_opts)
    end

    -- TODO: filter and sort do not actually have a way to use count to set a dest list nr
    vim.api.nvim_create_user_command("Qfilter", function(cargs)
        filter_cmd(cargs, false)
    end, { bang = true, count = true, nargs = "*" })

    vim.api.nvim_create_user_command("Lfilter", function(cargs)
        filter_cmd(cargs, true)
    end, { bang = true, count = true, nargs = "*" })

    -------------------------
    --- OPEN_CLOSE_TOGGLE ---
    -------------------------

    vim.api.nvim_create_user_command("Qopen", function(cargs)
        cargs = cargs or {}
        local count = cargs.count > 0 and cargs.count or nil
        eo._open_qflist({ always_resize = true, height = count })
    end, { count = 0 })

    vim.api.nvim_create_user_command("Lopen", function(cargs)
        cargs = cargs or {}
        local count = cargs.count > 0 and cargs.count or nil
        eo._open_loclist({ always_resize = true, height = count })
    end, { count = 0 })

    vim.api.nvim_create_user_command("Qclose", function()
        eo._close_qflist()
    end, {})

    vim.api.nvim_create_user_command("Lclose", function()
        eo._close_loclist()
    end, {})

    vim.api.nvim_create_user_command("Qtoggle", function()
        eo._toggle_qflist()
    end, {})

    vim.api.nvim_create_user_command("Ltoggle", function()
        eo._toggle_loclist()
    end, {})

    ------------------
    --- NAV_ACTION ---
    ------------------

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

    -----------------
    --- SORT CMDS ---
    -----------------

    local function sort_cmd(cargs, is_loclist)
        cargs = cargs or {}
        local fargs = cargs.fargs

        local sorts = require("mjm.error-list-sort").get_sort_names()
        assert(#sorts > 1, "No sort functions available")
        local sort_func = check_arg(fargs, sorts, "fname")

        local dir = check_arg(fargs, { "asc", "desc" }, "asc")
        local action = check_arg(fargs, actions, default_action)
        local count = cargs.count > 0 and cargs.count or nil

        et.sort(
            sort_func,
            { dir = dir },
            { action = action, count = count, is_loclist = is_loclist }
        )
    end

    vim.api.nvim_create_user_command("Qsort", function(cargs)
        sort_cmd(cargs, false)
    end, { nargs = "*" })

    vim.api.nvim_create_user_command("Lsort", function(cargs)
        sort_cmd(cargs, true)
    end, { nargs = "*" })

    -------------
    --- STACK ---
    -------------

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
