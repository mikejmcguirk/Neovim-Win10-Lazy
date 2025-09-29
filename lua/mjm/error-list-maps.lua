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

--- The keymaps need to all be set here to avoid eagerly requiring other modules
--- I have not been able to find a way to build the list at runtime without it being hard to read
--- and non-trivially affecting startup time

--- @alias QfRancherMapData{[1]:string[], [2]:string, [3]:string, [4]: string, [5]: function}

-- stylua: ignore
--- @type QfRancherMapData[]
local rancher_keymaps = {
    { nx, "<nop>", "<leader>q", "Avoid falling back to defaults", nil },
    { nx, "<nop>", "<leader>l", "Avoid falling back to defaults", nil },

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

    { nx, pqfr.."-Qfilter-n-cfilter)",   qp.."kl",         "Qfilter cfilter"..n..sc,  function() ef.cfilter({ keep = true }, { input_type = "vimsmart" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-r-cfilter)",   qp.."Kl",         "Qfilter cfilter"..r..sc,  function() ef.cfilter({ keep = true }, { input_type = "vimsmart" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-a-cfilter)",   qp.."<C-k>l",     "Qfilter cfilter"..a..sc,  function() ef.cfilter({ keep = true }, { input_type = "vimsmart" }, { action = "add", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-n-cfilter)",  qp.."rl",         "Qfilter! cfilter"..n..sc, function() ef.cfilter({ keep = false }, { input_type = "vimsmart" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-r-cfilter)",  qp.."Rl",         "Qfilter! cfilter"..r..sc, function() ef.cfilter({ keep = false }, { input_type = "vimsmart" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-a-cfilter)",  qp.."<C-r>l",     "Qfilter! cfilter"..a..sc, function() ef.cfilter({ keep = false }, { input_type = "vimsmart" }, { action = "add", is_loclist = false }) end},

    { nx, pqfr.."-Qfilter-n-CFILTER)",   qp.."kL",         "Qfilter cfilter"..n..cs,  function() ef.cfilter({ keep = true }, { input_type = "sensitive" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-r-CFILTER)",   qp.."KL",         "Qfilter cfilter"..r..cs,  function() ef.cfilter({ keep = true }, { input_type = "sensitive" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-a-CFILTER)",   qp.."<C-k>L",     "Qfilter cfilter"..a..cs,  function() ef.cfilter({ keep = true }, { input_type = "sensitive" }, { action = "add", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-n-CFILTER)",  qp.."rL",         "Qfilter! cfilter"..n..cs, function() ef.cfilter({ keep = false }, { input_type = "sensitive" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-r-CFILTER)",  qp.."RL",         "Qfilter! cfilter"..r..cs, function() ef.cfilter({ keep = false }, { input_type = "sensitive" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-a-CFILTER)",  qp.."<C-r>L",     "Qfilter! cfilter"..a..cs, function() ef.cfilter({ keep = false }, { input_type = "sensitive" }, { action = "add", is_loclist = false }) end},

    { nx, pqfr.."-Qfilter-n-cfilterX)",  qp.."k<C-l>",     "Qfilter cfilter"..n..rx,  function() ef.cfilter({ keep = true }, { input_type = "regex" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-r-cfilterX)",  qp.."K<C-l>",     "Qfilter cfilter"..r..rx,  function() ef.cfilter({ keep = true }, { input_type = "regex" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-a-cfilterX)",  qp.."<C-k><C-l>", "Qfilter cfilter"..a..rx,  function() ef.cfilter({ keep = true }, { input_type = "regex" }, { action = "add", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-n-cfilterX)", qp.."r<C-l>",     "Qfilter! cfilter"..n..rx, function() ef.cfilter({ keep = false }, { input_type = "regex" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-r-cfilterX)", qp.."R<C-l>",     "Qfilter! cfilter"..r..rx, function() ef.cfilter({ keep = false }, { input_type = "regex" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-a-cfilterX)", qp.."<C-r><C-l>", "Qfilter! cfilter"..a..rx, function() ef.cfilter({ keep = false }, { input_type = "regex" }, { action = "add", is_loclist = false }) end},

    { nx, pqfr.."-Lfilter-n-cfilter)",   lp.."kl",         "Lfilter cfilter"..n..sc,  function() ef.cfilter({ keep = true }, { input_type = "vimsmart" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-r-cfilter)",   lp.."Kl",         "Lfilter cfilter"..r..sc,  function() ef.cfilter({ keep = true }, { input_type = "vimsmart" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-a-cfilter)",   lp.."<C-k>l",     "Lfilter cfilter"..a..sc,  function() ef.cfilter({ keep = true }, { input_type = "vimsmart" }, { action = "add", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-n-cfilter)",  lp.."rl",         "Lfilter! cfilter"..n..sc, function() ef.cfilter({ keep = false }, { input_type = "vimsmart" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-r-cfilter)",  lp.."Rl",         "Lfilter! cfilter"..r..sc, function() ef.cfilter({ keep = false }, { input_type = "vimsmart" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-a-cfilter)",  lp.."<C-r>l",     "Lfilter! cfilter"..a..sc, function() ef.cfilter({ keep = false }, { input_type = "vimsmart" }, { action = "add", is_loclist = true }) end},

    { nx, pqfr.."-Lfilter-n-CFILTER)",   lp.."kL",         "Lfilter cfilter"..n..cs,  function() ef.cfilter({ keep = true }, { input_type = "sensitive" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-r-CFILTER)",   lp.."KL",         "Lfilter cfilter"..r..cs,  function() ef.cfilter({ keep = true }, { input_type = "sensitive" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-a-CFILTER)",   lp.."<C-k>L",     "Lfilter cfilter"..a..cs,  function() ef.cfilter({ keep = true }, { input_type = "sensitive" }, { action = "add", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-n-CFILTER)",  lp.."rL",         "Lfilter! cfilter"..n..cs, function() ef.cfilter({ keep = false }, { input_type = "sensitive" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-r-CFILTER)",  lp.."RL",         "Lfilter! cfilter"..r..cs, function() ef.cfilter({ keep = false }, { input_type = "sensitive" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-a-CFILTER)",  lp.."<C-r>L",     "Lfilter! cfilter"..a..cs, function() ef.cfilter({ keep = false }, { input_type = "sensitive" }, { action = "add", is_loclist = true }) end},

    { nx, pqfr.."-Lfilter-n-cfilterX)",  lp.."k<C-l>",     "Lfilter cfilter"..n..rx,  function() ef.cfilter({ keep = true }, { input_type = "regex" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-r-cfilterX)",  lp.."K<C-l>",     "Lfilter cfilter"..r..rx,  function() ef.cfilter({ keep = true }, { input_type = "regex" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-a-cfilterX)",  lp.."<C-k><C-l>", "Lfilter cfilter"..a..rx,  function() ef.cfilter({ keep = true }, { input_type = "regex" }, { action = "add", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-n-cfilterX)", lp.."r<C-l>",     "Lfilter! cfilter"..n..rx, function() ef.cfilter({ keep = false }, { input_type = "regex" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-r-cfilterX)", lp.."R<C-l>",     "Lfilter! cfilter"..r..rx, function() ef.cfilter({ keep = false }, { input_type = "regex" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-a-cfilterX)", lp.."<C-r><C-l>", "Lfilter! cfilter"..a..rx, function() ef.cfilter({ keep = false }, { input_type = "regex" }, { action = "add", is_loclist = true }) end},

    --- Fname ---

    { nx, pqfr.."-Qfilter-n-fname)",     qp.."kf",         "Qfilter fname"..n..sc,    function() ef.fname({ keep = true }, { input_type = "vimsmart" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-r-fname)",     qp.."Kf",         "Qfilter fname"..r..sc,    function() ef.fname({ keep = true }, { input_type = "vimsmart" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-a-fname)",     qp.."<C-k>f",     "Qfilter fname"..a..sc,    function() ef.fname({ keep = true }, { input_type = "vimsmart" }, { action = "add", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-n-fname)",    qp.."rf",         "Qfilter! fname"..n..sc,   function() ef.fname({ keep = false }, { input_type = "vimsmart" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-r-fname)",    qp.."Rf",         "Qfilter! fname"..r..sc,   function() ef.fname({ keep = false }, { input_type = "vimsmart" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-a-fname)",    qp.."<C-r>f",     "Qfilter! fname"..a..sc,   function() ef.fname({ keep = false }, { input_type = "vimsmart" }, { action = "add", is_loclist = false }) end},

    { nx, pqfr.."-Qfilter-n-FNAME)",     qp.."kF",         "Qfilter fname"..n..cs,    function() ef.fname({ keep = true }, { input_type = "sensitive" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-r-FNAME)",     qp.."KF",         "Qfilter fname"..r..cs,    function() ef.fname({ keep = true }, { input_type = "sensitive" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-a-FNAME)",     qp.."<C-k>F",     "Qfilter fname"..a..cs,    function() ef.fname({ keep = true }, { input_type = "sensitive" }, { action = "add", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-n-FNAME)",    qp.."rF",         "Qfilter! fname"..n..cs,   function() ef.fname({ keep = false }, { input_type = "sensitive" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-r-FNAME)",    qp.."RF",         "Qfilter! fname"..r..cs,   function() ef.fname({ keep = false }, { input_type = "sensitive" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-a-FNAME)",    qp.."<C-r>F",     "Qfilter! fname"..a..cs,   function() ef.fname({ keep = false }, { input_type = "sensitive" }, { action = "add", is_loclist = false }) end},

    { nx, pqfr.."-Qfilter-n-fnameX)",    qp.."k<C-f>",     "Qfilter fname"..n..rx,    function() ef.fname({ keep = true }, { input_type = "regex" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-r-fnameX)",    qp.."K<C-f>",     "Qfilter fname"..r..rx,    function() ef.fname({ keep = true }, { input_type = "regex" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-a-fnameX)",    qp.."<C-k><C-f>", "Qfilter fname"..a..rx,    function() ef.fname({ keep = true }, { input_type = "regex" }, { action = "add", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-n-fnameX)",   qp.."r<C-f>",     "Qfilter! fname"..n..rx,   function() ef.fname({ keep = false }, { input_type = "regex" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-r-fnameX)",   qp.."R<C-f>",     "Qfilter! fname"..r..rx,   function() ef.fname({ keep = false }, { input_type = "regex" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-a-fnameX)",   qp.."<C-r><C-f>", "Qfilter! fname"..a..rx,   function() ef.fname({ keep = false }, { input_type = "regex" }, { action = "add", is_loclist = false }) end},

    { nx, pqfr.."-Lfilter-n-fname)",     lp.."kf",         "Lfilter fname"..n..sc,    function() ef.fname({ keep = true }, { input_type = "vimsmart" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-r-fname)",     lp.."Kf",         "Lfilter fname"..r..sc,    function() ef.fname({ keep = true }, { input_type = "vimsmart" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-a-fname)",     lp.."<C-k>f",     "Lfilter fname"..a..sc,    function() ef.fname({ keep = true }, { input_type = "vimsmart" }, { action = "add", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-n-fname)",    lp.."rf",         "Lfilter! fname"..n..sc,   function() ef.fname({ keep = false }, { input_type = "vimsmart" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-r-fname)",    lp.."Rf",         "Lfilter! fname"..r..sc,   function() ef.fname({ keep = false }, { input_type = "vimsmart" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-a-fname)",    lp.."<C-r>f",     "Lfilter! fname"..a..sc,   function() ef.fname({ keep = false }, { input_type = "vimsmart" }, { action = "add", is_loclist = true }) end},

    { nx, pqfr.."-Lfilter-n-FNAME)",     lp.."kF",         "Lfilter fname"..n..cs,    function() ef.fname({ keep = true }, { input_type = "sensitive" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-r-FNAME)",     lp.."KF",         "Lfilter fname"..r..cs,    function() ef.fname({ keep = true }, { input_type = "sensitive" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-a-FNAME)",     lp.."<C-k>F",     "Lfilter fname"..a..cs,    function() ef.fname({ keep = true }, { input_type = "sensitive" }, { action = "add", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-n-FNAME)",    lp.."rF",         "Lfilter! fname"..n..cs,   function() ef.fname({ keep = false }, { input_type = "sensitive" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-r-FNAME)",    lp.."RF",         "Lfilter! fname"..r..cs,   function() ef.fname({ keep = false }, { input_type = "sensitive" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-a-FNAME)",    lp.."<C-r>F",     "Lfilter! fname"..a..cs,   function() ef.fname({ keep = false }, { input_type = "sensitive" }, { action = "add", is_loclist = true }) end},

    { nx, pqfr.."-Lfilter-n-fnameX)",    lp.."k<C-f>",     "Lfilter fname"..n..rx,    function() ef.fname({ keep = true }, { input_type = "regex" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-r-fnameX)",    lp.."K<C-f>",     "Lfilter fname"..r..rx,    function() ef.fname({ keep = true }, { input_type = "regex" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-a-fnameX)",    lp.."<C-k><C-f>", "Lfilter fname"..a..rx,    function() ef.fname({ keep = true }, { input_type = "regex" }, { action = "add", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-n-fnameX)",   lp.."r<C-f>",     "Lfilter! fname"..n..rx,   function() ef.fname({ keep = false }, { input_type = "regex" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-r-fnameX)",   lp.."R<C-f>",     "Lfilter! fname"..r..rx,   function() ef.fname({ keep = false }, { input_type = "regex" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-a-fnameX)",   lp.."<C-r><C-f>", "Lfilter! fname"..a..rx,   function() ef.fname({ keep = false }, { input_type = "regex" }, { action = "add", is_loclist = true }) end},

    --- Text ---

    { nx, pqfr.."-Qfilter-n-text)",      qp.."ke",         "Qfilter text"..n..sc,     function() ef.text({ keep = true }, { input_type = "vimsmart" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-r-text)",      qp.."Ke",         "Qfilter text"..r..sc,     function() ef.text({ keep = true }, { input_type = "vimsmart" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-a-text)",      qp.."<C-k>e",     "Qfilter text"..a..sc,     function() ef.text({ keep = true }, { input_type = "vimsmart" }, { action = "add", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-n-text)",     qp.."re",         "Qfilter! text"..n..sc,    function() ef.text({ keep = false }, { input_type = "vimsmart" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-r-text)",     qp.."Re",         "Qfilter! text"..r..sc,    function() ef.text({ keep = false }, { input_type = "vimsmart" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-a-text)",     qp.."<C-r>e",     "Qfilter! text"..a..sc,    function() ef.text({ keep = false }, { input_type = "vimsmart" }, { action = "add", is_loclist = false }) end},

    { nx, pqfr.."-Qfilter-n-TEXT)",      qp.."kE",         "Qfilter text"..n..cs,     function() ef.text({ keep = true }, { input_type = "sensitive" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-r-TEXT)",      qp.."KE",         "Qfilter text"..r..cs,     function() ef.text({ keep = true }, { input_type = "sensitive" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-a-TEXT)",      qp.."<C-k>E",     "Qfilter text"..a..cs,     function() ef.text({ keep = true }, { input_type = "sensitive" }, { action = "add", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-n-TEXT)",     qp.."rE",         "Qfilter! text"..n..cs,    function() ef.text({ keep = false }, { input_type = "sensitive" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-r-TEXT)",     qp.."RE",         "Qfilter! text"..r..cs,    function() ef.text({ keep = false }, { input_type = "sensitive" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-a-TEXT)",     qp.."<C-r>E",     "Qfilter! text"..a..cs,    function() ef.text({ keep = false }, { input_type = "sensitive" }, { action = "add", is_loclist = false }) end},

    { nx, pqfr.."-Qfilter-n-textX)",     qp.."k<C-e>",     "Qfilter text"..n..rx,     function() ef.text({ keep = true }, { input_type = "regex" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-r-textX)",     qp.."K<C-e>",     "Qfilter text"..r..rx,     function() ef.text({ keep = true }, { input_type = "regex" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-a-textX)",     qp.."<C-k><C-e>", "Qfilter text"..a..rx,     function() ef.text({ keep = true }, { input_type = "regex" }, { action = "add", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-n-textX)",    qp.."r<C-e>",     "Qfilter! text"..n..rx,    function() ef.text({ keep = false }, { input_type = "regex" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-r-textX)",    qp.."R<C-e>",     "Qfilter! text"..r..rx,    function() ef.text({ keep = false }, { input_type = "regex" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-a-textX)",    qp.."<C-r><C-e>", "Qfilter! text"..a..rx,    function() ef.text({ keep = false }, { input_type = "regex" }, { action = "add", is_loclist = false }) end},

    { nx, pqfr.."-Lfilter-n-text)",      lp.."ke",         "Lfilter text"..n..sc,     function() ef.text({ keep = true }, { input_type = "vimsmart" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-r-text)",      lp.."Ke",         "Lfilter text"..r..sc,     function() ef.text({ keep = true }, { input_type = "vimsmart" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-a-text)",      lp.."<C-k>e",     "Lfilter text"..a..sc,     function() ef.text({ keep = true }, { input_type = "vimsmart" }, { action = "add", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-n-text)",     lp.."re",         "Lfilter! text"..n..sc,    function() ef.text({ keep = false }, { input_type = "vimsmart" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-r-text)",     lp.."Re",         "Lfilter! text"..r..sc,    function() ef.text({ keep = false }, { input_type = "vimsmart" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-a-text)",     lp.."<C-r>e",     "Lfilter! text"..a..sc,    function() ef.text({ keep = false }, { input_type = "vimsmart" }, { action = "add", is_loclist = true }) end},

    { nx, pqfr.."-Lfilter-n-TEXT)",      lp.."kE",         "Lfilter text"..n..cs,     function() ef.text({ keep = true }, { input_type = "sensitive" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-r-TEXT)",      lp.."KE",         "Lfilter text"..r..cs,     function() ef.text({ keep = true }, { input_type = "sensitive" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-a-TEXT)",      lp.."<C-k>E",     "Lfilter text"..a..cs,     function() ef.text({ keep = true }, { input_type = "sensitive" }, { action = "add", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-n-TEXT)",     lp.."rE",         "Lfilter! text"..n..cs,    function() ef.text({ keep = false }, { input_type = "sensitive" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-r-TEXT)",     lp.."RE",         "Lfilter! text"..r..cs,    function() ef.text({ keep = false }, { input_type = "sensitive" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-a-TEXT)",     lp.."<C-r>E",     "Lfilter! text"..a..cs,    function() ef.text({ keep = false }, { input_type = "sensitive" }, { action = "add", is_loclist = true }) end},

    { nx, pqfr.."-Lfilter-n-textX)",     lp.."k<C-e>",     "Lfilter text"..n..rx,     function() ef.text({ keep = true }, { input_type = "regex" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-r-textX)",     lp.."K<C-e>",     "Lfilter text"..r..rx,     function() ef.text({ keep = true }, { input_type = "regex" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-a-textX)",     lp.."<C-k><C-e>", "Lfilter text"..a..rx,     function() ef.text({ keep = true }, { input_type = "regex" }, { action = "add", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-n-textX)",    lp.."r<C-e>",     "Lfilter! text"..n..rx,    function() ef.text({ keep = false }, { input_type = "regex" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-r-textX)",    lp.."R<C-e>",     "Lfilter! text"..r..rx,    function() ef.text({ keep = false }, { input_type = "regex" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-a-textX)",    lp.."<C-r><C-e>", "Lfilter! text"..a..rx,    function() ef.text({ keep = false }, { input_type = "regex" }, { action = "add", is_loclist = true }) end},

    --- Lnum ---

    { nx, pqfr.."-Qfilter-n-lnum)",      qp.."kn",         "Qfilter lnum"..n..sc,     function() ef.lnum({ keep = true }, { input_type = "vimsmart" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-r-lnum)",      qp.."Kn",         "Qfilter lnum"..r..sc,     function() ef.lnum({ keep = true }, { input_type = "vimsmart" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-a-lnum)",      qp.."<C-k>n",     "Qfilter lnum"..a..sc,     function() ef.lnum({ keep = true }, { input_type = "vimsmart" }, { action = "add", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-n-lnum)",     qp.."rn",         "Qfilter! lnum"..n..sc,    function() ef.lnum({ keep = false }, { input_type = "vimsmart" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-r-lnum)",     qp.."Rn",         "Qfilter! lnum"..r..sc,    function() ef.lnum({ keep = false }, { input_type = "vimsmart" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-a-lnum)",     qp.."<C-r>n",     "Qfilter! lnum"..a..sc,    function() ef.lnum({ keep = false }, { input_type = "vimsmart" }, { action = "add", is_loclist = false }) end},

    { nx, pqfr.."-Qfilter-n-LNUM)",      qp.."kN",         "Qfilter lnum"..n..cs,     function() ef.lnum({ keep = true }, { input_type = "sensitive" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-r-LNUM)",      qp.."KN",         "Qfilter lnum"..r..cs,     function() ef.lnum({ keep = true }, { input_type = "sensitive" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-a-LNUM)",      qp.."<C-k>N",     "Qfilter lnum"..a..cs,     function() ef.lnum({ keep = true }, { input_type = "sensitive" }, { action = "add", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-n-LNUM)",     qp.."rN",         "Qfilter! lnum"..n..cs,    function() ef.lnum({ keep = false }, { input_type = "sensitive" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-r-LNUM)",     qp.."RN",         "Qfilter! lnum"..r..cs,    function() ef.lnum({ keep = false }, { input_type = "sensitive" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-a-LNUM)",     qp.."<C-r>N",     "Qfilter! lnum"..a..cs,    function() ef.lnum({ keep = false }, { input_type = "sensitive" }, { action = "add", is_loclist = false }) end},

    { nx, pqfr.."-Qfilter-n-lnumX)",     qp.."k<C-n>",     "Qfilter lnum"..n..rx,     function() ef.lnum({ keep = true }, { input_type = "regex" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-r-lnumX)",     qp.."K<C-n>",     "Qfilter lnum"..r..rx,     function() ef.lnum({ keep = true }, { input_type = "regex" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-a-lnumX)",     qp.."<C-k><C-n>", "Qfilter lnum"..a..rx,     function() ef.lnum({ keep = true }, { input_type = "regex" }, { action = "add", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-n-lnumX)",    qp.."r<C-n>",     "Qfilter! lnum"..n..rx,    function() ef.lnum({ keep = false }, { input_type = "regex" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-r-lnumX)",    qp.."R<C-n>",     "Qfilter! lnum"..r..rx,    function() ef.lnum({ keep = false }, { input_type = "regex" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-a-lnumX)",    qp.."<C-r><C-n>", "Qfilter! lnum"..a..rx,    function() ef.lnum({ keep = false }, { input_type = "regex" }, { action = "add", is_loclist = false }) end},

    { nx, pqfr.."-Lfilter-n-lnum)",      lp.."kn",         "Lfilter lnum"..n..sc,     function() ef.lnum({ keep = true }, { input_type = "vimsmart" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-r-lnum)",      lp.."Kn",         "Lfilter lnum"..r..sc,     function() ef.lnum({ keep = true }, { input_type = "vimsmart" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-a-lnum)",      lp.."<C-k>n",     "Lfilter lnum"..a..sc,     function() ef.lnum({ keep = true }, { input_type = "vimsmart" }, { action = "add", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-n-lnum)",     lp.."rn",         "Lfilter! lnum"..n..sc,    function() ef.lnum({ keep = false }, { input_type = "vimsmart" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-r-lnum)",     lp.."Rn",         "Lfilter! lnum"..r..sc,    function() ef.lnum({ keep = false }, { input_type = "vimsmart" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-a-lnum)",     lp.."<C-r>n",     "Lfilter! lnum"..a..sc,    function() ef.lnum({ keep = false }, { input_type = "vimsmart" }, { action = "add", is_loclist = true }) end},

    { nx, pqfr.."-Lfilter-n-LNUM)",      lp.."kN",         "Lfilter lnum"..n..cs,     function() ef.lnum({ keep = true }, { input_type = "sensitive" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-r-LNUM)",      lp.."KN",         "Lfilter lnum"..r..cs,     function() ef.lnum({ keep = true }, { input_type = "sensitive" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-a-LNUM)",      lp.."<C-k>N",     "Lfilter lnum"..a..cs,     function() ef.lnum({ keep = true }, { input_type = "sensitive" }, { action = "add", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-n-LNUM)",     lp.."rN",         "Lfilter! lnum"..n..cs,    function() ef.lnum({ keep = false }, { input_type = "sensitive" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-r-LNUM)",     lp.."RN",         "Lfilter! lnum"..r..cs,    function() ef.lnum({ keep = false }, { input_type = "sensitive" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-a-LNUM)",     lp.."<C-r>N",     "Lfilter! lnum"..a..cs,    function() ef.lnum({ keep = false }, { input_type = "sensitive" }, { action = "add", is_loclist = true }) end},

    { nx, pqfr.."-Lfilter-n-lnumX)",     lp.."k<C-n>",     "Lfilter lnum"..n..rx,     function() ef.lnum({ keep = true }, { input_type = "regex" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-r-lnumX)",     lp.."K<C-n>",     "Lfilter lnum"..r..rx,     function() ef.lnum({ keep = true }, { input_type = "regex" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-a-lnumX)",     lp.."<C-k><C-n>", "Lfilter lnum"..a..rx,     function() ef.lnum({ keep = true }, { input_type = "regex" }, { action = "add", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-n-lnumX)",    lp.."r<C-n>",     "Lfilter! lnum"..n..rx,    function() ef.lnum({ keep = false }, { input_type = "regex" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-r-lnumX)",    lp.."R<C-n>",     "Lfilter! lnum"..r..rx,    function() ef.lnum({ keep = false }, { input_type = "regex" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-a-lnumX)",    lp.."<C-r><C-n>", "Lfilter! lnum"..a..rx,    function() ef.lnum({ keep = false }, { input_type = "regex" }, { action = "add", is_loclist = true }) end},

    --- Type ---

    { nx, pqfr.."-Qfilter-n-type)",      qp.."kt",         "Qfilter type"..n..sc,     function() ef.type({ keep = true }, { input_type = "vimsmart" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-r-type)",      qp.."Kt",         "Qfilter type"..r..sc,     function() ef.type({ keep = true }, { input_type = "vimsmart" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-a-type)",      qp.."<C-k>t",     "Qfilter type"..a..sc,     function() ef.type({ keep = true }, { input_type = "vimsmart" }, { action = "add", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-n-type)",     qp.."rt",         "Qfilter! type"..n..sc,    function() ef.type({ keep = false }, { input_type = "vimsmart" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-r-type)",     qp.."Rt",         "Qfilter! type"..r..sc,    function() ef.type({ keep = false }, { input_type = "vimsmart" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-a-type)",     qp.."<C-r>t",     "Qfilter! type"..a..sc,    function() ef.type({ keep = false }, { input_type = "vimsmart" }, { action = "add", is_loclist = false }) end},

    { nx, pqfr.."-Qfilter-n-TYPE)",      qp.."kT",         "Qfilter type"..n..cs,     function() ef.type({ keep = true }, { input_type = "sensitive" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-r-TYPE)",      qp.."KT",         "Qfilter type"..r..cs,     function() ef.type({ keep = true }, { input_type = "sensitive" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-a-TYPE)",      qp.."<C-k>T",     "Qfilter type"..a..cs,     function() ef.type({ keep = true }, { input_type = "sensitive" }, { action = "add", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-n-TYPE)",     qp.."rT",         "Qfilter! type"..n..cs,    function() ef.type({ keep = false }, { input_type = "sensitive" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-r-TYPE)",     qp.."RT",         "Qfilter! type"..r..cs,    function() ef.type({ keep = false }, { input_type = "sensitive" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-a-TYPE)",     qp.."<C-r>T",     "Qfilter! type"..a..cs,    function() ef.type({ keep = false }, { input_type = "sensitive" }, { action = "add", is_loclist = false }) end},

    { nx, pqfr.."-Qfilter-n-typeX)",     qp.."k<C-t>",     "Qfilter type"..n..rx,     function() ef.type({ keep = true }, { input_type = "regex" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-r-typeX)",     qp.."K<C-t>",     "Qfilter type"..r..rx,     function() ef.type({ keep = true }, { input_type = "regex" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter-a-typeX)",     qp.."<C-k><C-t>", "Qfilter type"..a..rx,     function() ef.type({ keep = true }, { input_type = "regex" }, { action = "add", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-n-typeX)",    qp.."r<C-t>",     "Qfilter! type"..n..rx,    function() ef.type({ keep = false }, { input_type = "regex" }, { action = "new", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-r-typeX)",    qp.."R<C-t>",     "Qfilter! type"..r..rx,    function() ef.type({ keep = false }, { input_type = "regex" }, { action = "replace", is_loclist = false }) end},
    { nx, pqfr.."-Qfilter!-a-typeX)",    qp.."<C-r><C-t>", "Qfilter! type"..a..rx,    function() ef.type({ keep = false }, { input_type = "regex" }, { action = "add", is_loclist = false }) end},

    { nx, pqfr.."-Lfilter-n-type)",      lp.."kt",         "Lfilter type"..n..sc,     function() ef.type({ keep = true }, { input_type = "vimsmart" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-r-type)",      lp.."Kt",         "Lfilter type"..r..sc,     function() ef.type({ keep = true }, { input_type = "vimsmart" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-a-type)",      lp.."<C-k>t",     "Lfilter type"..a..sc,     function() ef.type({ keep = true }, { input_type = "vimsmart" }, { action = "add", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-n-type)",     lp.."rt",         "Lfilter! type"..n..sc,    function() ef.type({ keep = false }, { input_type = "vimsmart" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-r-type)",     lp.."Rt",         "Lfilter! type"..r..sc,    function() ef.type({ keep = false }, { input_type = "vimsmart" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-a-type)",     lp.."<C-r>t",     "Lfilter! type"..a..sc,    function() ef.type({ keep = false }, { input_type = "vimsmart" }, { action = "add", is_loclist = true }) end},

    { nx, pqfr.."-Lfilter-n-TYPE)",      lp.."kT",         "Lfilter type"..n..cs,     function() ef.type({ keep = true }, { input_type = "sensitive" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-r-TYPE)",      lp.."KT",         "Lfilter type"..r..cs,     function() ef.type({ keep = true }, { input_type = "sensitive" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-a-TYPE)",      lp.."<C-k>T",     "Lfilter type"..a..cs,     function() ef.type({ keep = true }, { input_type = "sensitive" }, { action = "add", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-n-TYPE)",     lp.."rT",         "Lfilter! type"..n..cs,    function() ef.type({ keep = false }, { input_type = "sensitive" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-r-TYPE)",     lp.."RT",         "Lfilter! type"..r..cs,    function() ef.type({ keep = false }, { input_type = "sensitive" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-a-TYPE)",     lp.."<C-r>T",     "Lfilter! type"..a..cs,    function() ef.type({ keep = false }, { input_type = "sensitive" }, { action = "add", is_loclist = true }) end},

    { nx, pqfr.."-Lfilter-n-typeX)",     lp.."k<C-t>",     "Lfilter type"..n..rx,     function() ef.type({ keep = true }, { input_type = "regex" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-r-typeX)",     lp.."K<C-t>",     "Lfilter type"..r..rx,     function() ef.type({ keep = true }, { input_type = "regex" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter-a-typeX)",     lp.."<C-k><C-t>", "Lfilter type"..a..rx,     function() ef.type({ keep = true }, { input_type = "regex" }, { action = "add", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-n-typeX)",    lp.."r<C-t>",     "Lfilter! type"..n..rx,    function() ef.type({ keep = false }, { input_type = "regex" }, { action = "new", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-r-typeX)",    lp.."R<C-t>",     "Lfilter! type"..r..rx,    function() ef.type({ keep = false }, { input_type = "regex" }, { action = "replace", is_loclist = true }) end},
    { nx, pqfr.."-Lfilter!-a-typeX)",    lp.."<C-r><C-t>", "Lfilter! type"..a..rx,    function() ef.type({ keep = false }, { input_type = "regex" }, { action = "add", is_loclist = true }) end},

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
    { nx, pqfr.."-grep-n-cwd)",    qp.."gd",         "Qgrep cwd, new"..sc,           function() eg.grep_cwd(grep_smart_case, sys_new) end },
    { nx, pqfr.."-grep-r-cwd)",    qp.."Gd",         "Qgrep cwd, replace"..sc,       function() eg.grep_cwd(grep_smart_case, sys_replace) end },
    { nx, pqfr.."-grep-a-cwd)",    qp.."<C-g>d",     "Qgrep cwd, add"..sc,           function() eg.grep_cwd(grep_smart_case, sys_add) end },
    { nx, pqfr.."-grep-n-CWD)",    qp.."gD",         "Qgrep cwd, new"..cs,           function() eg.grep_cwd(grep_case_sensitive, sys_new) end },
    { nx, pqfr.."-grep-r-CWD)",    qp.."GD",         "Qgrep cwd, replace"..cs,       function() eg.grep_cwd(grep_case_sensitive, sys_replace) end },
    { nx, pqfr.."-grep-a-CWD)",    qp.."<C-g>D",     "Qgrep cwd, add"..cs,           function() eg.grep_cwd(grep_case_sensitive, sys_add) end },
    { nx, pqfr.."-grep-n-cwdX)",   qp.."g<C-d>",     "Qgrep cwd, new"..rx,           function() eg.grep_cwd({}, sys_new) end },
    { nx, pqfr.."-grep-r-cwdX)",   qp.."G<C-d>",     "Qgrep cwd, replace"..rx,       function() eg.grep_cwd({}, sys_replace) end },
    { nx, pqfr.."-grep-a-cwdX)",   qp.."<C-g><C-d>", "Qgrep cwd, add"..rx,           function() eg.grep_cwd({}, sys_add) end },

    { nx, pqfr.."-lgrep-n-cwd)",   lp.."gd",         "Lgrep cwd, new"..sc,           function() eg.grep_cwd(grep_smart_case, sys_lnew) end },
    { nx, pqfr.."-lgrep-r-cwd)",   lp.."Gd",         "Lgrep cwd, replace"..sc,       function() eg.grep_cwd(grep_smart_case, sys_lreplace) end },
    { nx, pqfr.."-lgrep-a-cwd)",   lp.."<C-g>d",     "Lgrep cwd, add"..sc,           function() eg.grep_cwd(grep_smart_case, sys_ladd) end },
    { nx, pqfr.."-lgrep-n-CWD)",   lp.."gD",         "Lgrep cwd, new"..cs,           function() eg.grep_cwd(grep_case_sensitive, sys_lnew) end },
    { nx, pqfr.."-lgrep-r-CWD)",   lp.."GD",         "Lgrep cwd, replace"..cs,       function() eg.grep_cwd(grep_case_sensitive, sys_lreplace) end },
    { nx, pqfr.."-lgrep-a-CWD)",   lp.."<C-g>D",     "Lgrep cwd, add"..cs,           function() eg.grep_cwd(grep_case_sensitive, sys_ladd) end },
    { nx, pqfr.."-lgrep-n-cwdX)",  lp.."g<C-d>",     "Lgrep cwd, new"..rx,           function() eg.grep_cwd({}, sys_lnew) end },
    { nx, pqfr.."-lgrep-r-cwdX)",  lp.."G<C-d>",     "Lgrep cwd, replace"..rx,       function() eg.grep_cwd({}, sys_lreplace) end },
    { nx, pqfr.."-lgrep-a-cwdX)",  lp.."<C-g><C-d>", "Lgrep cwd, add"..rx,           function() eg.grep_cwd({}, sys_ladd) end },

    { nx, pqfr.."-grep-n-help)",   qp.."gh",         "Qgrep docs, new"..sc,          function() eg.grep_help(grep_smart_case, sys_help_new) end },
    { nx, pqfr.."-grep-r-help)",   qp.."Gh",         "Qgrep docs, replace"..sc,      function() eg.grep_help(grep_smart_case, sys_help_replace) end },
    { nx, pqfr.."-grep-a-help)",   qp.."<C-g>h",     "Qgrep docs, add"..sc,          function() eg.grep_help(grep_smart_case, sys_help_add) end },
    { nx, pqfr.."-grep-n-HELP)",   qp.."gH",         "Qgrep docs, new"..cs,          function() eg.grep_help(grep_case_sensitive, sys_help_new) end },
    { nx, pqfr.."-grep-r-HELP)",   qp.."GH",         "Qgrep docs, replace"..cs,      function() eg.grep_help(grep_case_sensitive, sys_help_replace) end },
    { nx, pqfr.."-grep-a-HELP)",   qp.."<C-g>H",     "Qgrep docs, add"..cs,          function() eg.grep_help(grep_case_sensitive, sys_help_add) end },
    { nx, pqfr.."-grep-n-helpX)",  qp.."g<C-h>",     "Qgrep docs, new"..rx,          function() eg.grep_help({}, sys_help_new) end },
    { nx, pqfr.."-grep-r-helpX)",  qp.."G<C-h>",     "Qgrep docs, replace"..rx,      function() eg.grep_help({}, sys_help_replace) end },
    { nx, pqfr.."-grep-a-helpX)",  qp.."<C-g><C-h>", "Qgrep docs, add"..rx,          function() eg.grep_help({}, sys_help_add) end },

    { nx, pqfr.."-lgrep-n-help)",  lp.."gh",         "Lgrep docs, new"..sc,          function() eg.grep_help(grep_smart_case, sys_help_lnew) end },
    { nx, pqfr.."-lgrep-r-help)",  lp.."Gh",         "Lgrep docs, replace"..sc,      function() eg.grep_help(grep_smart_case, sys_help_lreplace) end },
    { nx, pqfr.."-lgrep-a-help)",  lp.."<C-g>h",     "Lgrep docs, add"..sc,          function() eg.grep_help(grep_smart_case, sys_help_ladd) end },
    { nx, pqfr.."-lgrep-n-HELP)",  lp.."gH",         "Lgrep docs, new"..cs,          function() eg.grep_help(grep_case_sensitive, sys_help_lnew) end },
    { nx, pqfr.."-lgrep-r-HELP)",  lp.."GH",         "Lgrep docs, replace"..cs,      function() eg.grep_help(grep_case_sensitive, sys_help_lreplace) end },
    { nx, pqfr.."-lgrep-a-HELP)",  lp.."<C-g>H",     "Lgrep docs, add"..cs,          function() eg.grep_help(grep_case_sensitive, sys_help_ladd) end },
    { nx, pqfr.."-lgrep-n-helpX)", lp.."g<C-h>",     "Lgrep docs, new"..rx,          function() eg.grep_help({}, sys_help_lnew) end },
    { nx, pqfr.."-lgrep-r-helpX)", lp.."G<C-h>",     "Lgrep docs, replace"..rx,      function() eg.grep_help({}, sys_help_lreplace) end },
    { nx, pqfr.."-lgrep-a-helpX)", lp.."<C-g><C-h>", "Lgrep docs, add"..rx,          function() eg.grep_help(grep_smart_case, sys_help_ladd) end },

    { nx, pqfr.."-grep-n-bufs)",   qp.."gu",         "Qgrep open bufs, new"..sc,     function() eg.grep_bufs(grep_smart_case, sys_new) end },
    { nx, pqfr.."-grep-r-bufs)",   qp.."Gu",         "Qgrep open bufs, replace"..sc, function() eg.grep_bufs(grep_smart_case, sys_replace) end },
    { nx, pqfr.."-grep-a-bufs)",   qp.."<C-g>u",     "Qgrep open bufs, add"..sc,     function() eg.grep_bufs(grep_smart_case, sys_add) end },
    { nx, pqfr.."-grep-n-BUFS)",   qp.."gU",         "Qgrep open bufs, new"..cs,     function() eg.grep_bufs(grep_case_sensitive, sys_new) end },
    { nx, pqfr.."-grep-r-BUFS)",   qp.."GU",         "Qgrep open bufs, replace"..cs, function() eg.grep_bufs(grep_case_sensitive, sys_replace) end },
    { nx, pqfr.."-grep-a-BUFS)",   qp.."<C-g>U",     "Qgrep open bufs, add"..cs,     function() eg.grep_bufs(grep_case_sensitive, sys_add) end },
    { nx, pqfr.."-grep-n-bufsX)",  qp.."g<C-u>",     "Qgrep open bufs, new"..rx,     function() eg.grep_bufs({}, sys_new) end },
    { nx, pqfr.."-grep-r-bufsX)",  qp.."G<C-u>",     "Qgrep open bufs, replace"..rx, function() eg.grep_bufs({}, sys_replace) end },
    { nx, pqfr.."-grep-a-bufsX)",  qp.."<C-g><C-u>", "Qgrep open bufs, add"..rx,     function() eg.grep_bufs({}, sys_add) end },

    { nx, pqfr.."-lgrep-n-cbuf)",  lp.."gu",         "Lgrep cur buf, new"..sc,       function() eg.grep_cbuf(grep_smart_case, sys_lnew) end },
    { nx, pqfr.."-lgrep-r-cbuf)",  lp.."Gu",         "Lgrep cur buf, replace"..sc,   function() eg.grep_cbuf(grep_smart_case, sys_lreplace) end },
    { nx, pqfr.."-lgrep-a-cbuf)",  lp.."<C-g>u",     "Lgrep cur buf, add"..sc,       function() eg.grep_cbuf(grep_smart_case, sys_ladd) end },
    { nx, pqfr.."-lgrep-n-CBUF)",  lp.."gU",         "Lgrep cur buf, new"..cs,       function() eg.grep_cbuf(grep_case_sensitive, sys_lnew) end },
    { nx, pqfr.."-lgrep-r-CBUF)",  lp.."GU",         "Lgrep cur buf, replace"..cs,   function() eg.grep_cbuf(grep_case_sensitive, sys_lreplace) end },
    { nx, pqfr.."-lgrep-a-CBUF)",  lp.."<C-g>U",     "Lgrep cur buf, add"..cs,       function() eg.grep_cbuf(grep_case_sensitive, sys_ladd) end },
    { nx, pqfr.."-lgrep-n-cbufX)", lp.."g<C-u>",     "Lgrep cur buf, new"..rx,       function() eg.grep_cbuf({}, sys_lnew) end },
    { nx, pqfr.."-lgrep-r-cbufX)", lp.."G<C-u>",     "Lgrep cur buf, replace"..rx,   function() eg.grep_cbuf({}, sys_lreplace) end },
    { nx, pqfr.."-lgrep-a-cbufX)", lp.."<C-g><C-u>", "Lgrep cur buf, add"..rx,       function() eg.grep_cbuf({}, sys_ladd) end },

    -------------------------
    --- OPEN/CLOSE/RESIZE ---
    -------------------------

    { nn, pqfr.."-open-qf-list)",   qp.."p", "Open the quickfix list",   function() eo.open_qflist({ always_resize = true, height = vim.v.count }) end },
    { nn, pqfr.."-close-qf-list)",  qp.."o", "Close the quickfix list",  function() eo.close_qflist() end },
    { nn, pqfr.."-toggle-qf-list)", qp.."q", "Toggle the quickfix list", function() eo.toggle_qflist()  end },
    { nn, pqfr.."-open-loclist)",   lp.."p", "Open the location list",   function() eo.open_loclist({ always_resize = true, height = vim.v.count }) end },
    { nn, pqfr.."-close-loclist)",  lp.."o", "Close the location list",  function() eo.close_loclist() end },
    { nn, pqfr.."-toggle-loclist)", lp.."l", "Toggle the location list", function() eo.toggle_loclist() end },

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

    { nn, pqfr.."-qsort-n-fname-asc)",       qp.."tf",  "Qsort by fname asc"..n,       function() et.sort("fname", { dir = "asc" }, { action = "new", is_loclist = false }) end },
    { nn, pqfr.."-qsort-n-fname-desc)",      qp.."tF",  "Qsort by fname desc"..n,      function() et.sort("fname", { dir = "desc" }, { action = "new", is_loclist = false }) end },
    { nn, pqfr.."-qsort-n-fname-diag-asc)",  qp.."tif", "Qsort by fname_diag asc"..n,  function() et.sort("fname_diag", { dir = "asc" }, { action = "new", is_loclist = false }) end },
    { nn, pqfr.."-qsort-n-fname-diag-desc)", qp.."tiF", "Qsort by fname_diag desc"..n, function() et.sort("fname_diag", { dir = "desc" }, { action = "new", is_loclist = false }) end },
    { nn, pqfr.."-qsort-n-severity-asc)",    qp.."tis", "Qsort by severity asc"..n,    function() et.sort("severity", { dir = "asc" }, { action = "new", is_loclist = false }) end },
    { nn, pqfr.."-qsort-n-severity-desc)",   qp.."tiS", "Qsort by severity desc"..n,   function() et.sort("severity", { dir = "desc" }, { action = "new", is_loclist = false }) end },
    { nn, pqfr.."-qsort-n-type-asc)",        qp.."tt",  "Qsort by type asc"..n,        function() et.sort("type", { dir = "asc" }, { action = "new", is_loclist = false }) end },
    { nn, pqfr.."-qsort-n-type-desc)",       qp.."tT",  "Qsort by type desc"..n,       function() et.sort("type", { dir = "desc" }, { action = "new", is_loclist = false }) end },

    { nn, pqfr.."-lsort-n-fname-asc)",       lp.."tf",  "Lsort by fname asc"..n,       function() et.sort("fname", { dir = "asc" }, { action = "new", is_loclist = true }) end },
    { nn, pqfr.."-lsort-n-fname-desc)",      lp.."tF",  "Lsort by fname desc"..n,      function() et.sort("fname", { dir = "desc" }, { action = "new", is_loclist = true }) end },
    { nn, pqfr.."-lsort-n-fname-diag-asc)",  lp.."tif", "Lsort by fname_diag asc"..n,  function() et.sort("fname_diag", { dir = "asc" }, { action = "new", is_loclist = true }) end },
    { nn, pqfr.."-lsort-n-fname-diag-desc)", lp.."tiF", "Lsort by fname_diag desc"..n, function() et.sort("fname_diag", { dir = "desc" }, { action = "new", is_loclist = true }) end },
    { nn, pqfr.."-lsort-n-severity-asc)",    lp.."tis", "Lsort by severity asc"..n,    function() et.sort("severity", { dir = "asc" }, { action = "new", is_loclist = true }) end },
    { nn, pqfr.."-lsort-n-severity-desc)",   lp.."tiS", "Lsort by severity desc"..n,   function() et.sort("severity", { dir = "desc" }, { action = "new", is_loclist = true }) end },
    { nn, pqfr.."-lsort-n-type-asc)",        lp.."tt",  "Lsort by type asc"..n,        function() et.sort("type", { dir = "asc" }, { action = "new", is_loclist = true }) end },
    { nn, pqfr.."-lsort-n-type-desc)",       lp.."tT",  "Lsort by type desc"..n,       function() et.sort("type", { dir = "desc" }, { action = "new", is_loclist = true }) end },

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

--------------
--- FILTER ---
--------------

local function create_filter_command(is_loclist)
    return function(cmd_opts)
        local filter_funcs = {
            cfilter = ef.cfilter,
            fname = ef.fname,
            lnum = ef.lnum,
            type = ef.type,
            text = ef.text,
        }

        local action = "new"
        local filter_name = "cfilter"
        local pattern = nil
        local action_set = false
        local filter_set = false
        local pattern_set = false

        for _, arg in ipairs(cmd_opts.fargs) do
            if not action_set and vim.tbl_contains({ "new", "add", "merge" }, arg) then
                action = (arg == "merge") and "add" or arg
                action_set = true
            elseif
                not filter_set
                and vim.tbl_contains({ "cfilter", "fname", "lnum", "type", "text" }, arg)
            then
                filter_name = arg
                filter_set = true
            elseif not pattern_set and vim.startswith(arg, "/") then
                pattern = arg:sub(2)
                pattern_set = true
            end
        end

        local keep = not cmd_opts.bang
        local filter_func = filter_funcs[filter_name]
        if not filter_func then
            vim.api.nvim_echo(
                { { "Invalid filter type: " .. filter_name, "ErrorMsg" } },
                true,
                { err = true }
            )
            return
        end

        local filter_opts = { keep = keep }
        local input_opts = { input_type = pattern and "regex" or "vimsmart", pattern = pattern }
        local output_opts = { is_loclist = is_loclist, action = action }

        filter_func(filter_opts, input_opts, output_opts)
    end
end

if vim.g.qf_rancher_set_default_cmds then
    vim.api.nvim_create_user_command(
        "Qfilter",
        create_filter_command(false),
        { bang = true, count = true, nargs = "*" }
    )

    vim.api.nvim_create_user_command(
        "Lfilter",
        create_filter_command(true),
        { bang = true, count = true, nargs = "*" }
    )
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

-------------------------
--- OPEN_CLOSE_TOGGLE ---
-------------------------

if vim.g.qf_rancher_set_default_cmds then
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

if vim.g.qf_rancher_set_default_cmds then
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

if vim.g.qf_rancher_set_default_cmds then
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
