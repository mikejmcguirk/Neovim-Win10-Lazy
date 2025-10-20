--- NOTE: The mappings and user commands are all here in order to avoid eagerly requiring every
--- module during startup

--- NOTE: In order for the defer require to work, all function calls must be inside of
--- anonymous functions. If you pass, for example, eo.closeqflist as a function reference, eo
--- needs to be evaluated at command creation

local api = vim.api

--------------------------
--- Map and Cmd Pieces ---
--------------------------

local sys_opt = { timeout = 4000 } ---@type QfrSystemOpts

local in_vimsmart = { input_type = "vimsmart" } ---@type QfrInputOpts
local in_sensitive = { input_type = "sensitive" } ---@type QfrInputOpts
local in_regex = { input_type = "regex" } ---@type QfrInputOpts

-- TODO: Reverse action and src_win

---@param action QfrAction
---@param src_win integer|nil
---@return QfrOutputOpts
local function get_output_opts(action, src_win)
    return { src_win = src_win, action = action, what = { nr = vim.v.count } }
end

---@return integer
local function cur_win()
    return api.nvim_get_current_win()
end

---@return QfrOutputOpts
local function new_qflist()
    return get_output_opts(" ", nil)
end

---@return QfrOutputOpts
local function replace_qflist()
    return get_output_opts("u", nil)
end

---@return QfrOutputOpts
-- local function add_qflist()
--     return get_output_opts("a", nil)
-- end
--
---@return QfrOutputOpts
local function new_loclist()
    return get_output_opts(" ", cur_win())
end

---@return QfrOutputOpts
local function replace_loclist()
    return get_output_opts("u", cur_win())
end

-- ---@return QfrOutputOpts
-- local function add_loclist()
--     return get_output_opts("a", cur_win())
-- end
--
local ea = Qfr_Defer_Require("mjm.error-list-stack") ---@type QfrStack
local ed = Qfr_Defer_Require("mjm.error-list-diag") ---@type QfRancherDiagnostics
local ef = Qfr_Defer_Require("mjm.error-list-filter") ---@type QfrFilter
local ei = Qfr_Defer_Require("mjm.error-list-filetype-funcs") ---@type QfRancherFiletypeFuncs
local eg = Qfr_Defer_Require("mjm.error-list-grep") ---@type QfrGrep
local en = Qfr_Defer_Require("mjm.error-list-nav-action") ---@type QfRancherNav
local eo = Qfr_Defer_Require("mjm.error-list-open") ---@type QfRancherOpen
local ep = Qfr_Defer_Require("mjm.error-list-preview") ---@type QfRancherPreview
local es = Qfr_Defer_Require("mjm.error-list-sort") ---@type QfRancherSort
-- local et = Qfr_Defer_Require("mjm.error-list-tools") ---@type QfRancherTools

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
-- local a = ", add"

local keep = { keep = true }
local nokeep = { keep = false }

--- The keymaps need to all be set here to avoid eagerly requiring other modules
--- I have not been able to find a way to build the list at runtime without it being hard to read
--- and non-trivially affecting startup time
--- TODO: Need to have settable options for mappings

-- TODO: Might be a way to do this without the big table
-- qg/qG/q<C-g> all relate to how the what table is set. What is standard across all maps
-- Means you can loop them
-- So as a first step, you can have the what settings in a table and use that as a loop
-- Move the different loop pieces over in steps
-- Might also lead to better thinking about the API

--- Mode(s), Plug Map, User Map, Desc, Action

---@alias QfRancherMapData{[1]:string[], [2]:string, [3]:string, [4]: string, [5]: function}

-- stylua: ignore
---@type QfRancherMapData[]
local rancher_keymaps = {
    -------------------
    --- DIAGNOSTICS ---
    -------------------

    { nn, pqfr.. "Qdiags-n-hint",  qp.."in", "All buffer diagnostics min hint"..n,         function() ed.diags_to_list({ filter = "min", level = vim.diagnostic.severity.HINT }, new_qflist()) end },
    { nn, pqfr.. "Qdiags-n-info",  qp.."if", "All buffer diagnostics min info"..n,         function() ed.diags_to_list({ filter = "min", level = vim.diagnostic.severity.INFO }, new_qflist()) end },
    { nn, pqfr.. "Qdiags-n-warn",  qp.."iw", "All buffer diagnostics min warn"..n,         function() ed.diags_to_list({ filter = "min", level = vim.diagnostic.severity.WARN }, new_qflist()) end },
    { nn, pqfr.. "Qdiags-n-error", qp.."ie", "All buffer diagnostics min error"..n,        function() ed.diags_to_list({ filter = "min", level = vim.diagnostic.severity.ERROR }, new_qflist()) end },
    { nn, pqfr.. "Qdiags-n-top",   qp.."it", "All buffer diagnostics top severity"..n,     function() ed.diags_to_list({ filter = "top", level = nil }, new_qflist()) end },

    { nn, pqfr.. "Ldiags-n-hint",  lp.."in", "Cur buf diagnostics min hint"..n,            function() ed.diags_to_list({ filter = "min", level = vim.diagnostic.severity.HINT }, new_loclist()) end },
    { nn, pqfr.. "Ldiags-n-info",  lp.."if", "Cur buf diagnostics min info"..n,            function() ed.diags_to_list({ filter = "min", level = vim.diagnostic.severity.INFO }, new_loclist()) end },
    { nn, pqfr.. "Ldiags-n-warn",  lp.."iw", "Cur buf diagnostics min warn"..n,            function() ed.diags_to_list({ filter = "min", level = vim.diagnostic.severity.WARN }, new_loclist()) end },
    { nn, pqfr.. "Ldiags-n-error", lp.."ie", "Cur buf diagnostics min error"..n,           function() ed.diags_to_list({ filter = "min", level = vim.diagnostic.severity.ERROR }, new_loclist()) end },
    { nn, pqfr.. "Ldiags-n-top",   lp.."it", "Cur buf diagnostics top severity"..n,        function() ed.diags_to_list({ filter = "top", level = nil }, new_loclist()) end },

    { nn, pqfr.. "Qdiags-n-HINT",  qp.."iN", "All buffer diagnostics only hint"..n,        function() ed.diags_to_list({ filter = "only", level = vim.diagnostic.severity.HINT }, new_qflist()) end },
    { nn, pqfr.. "Qdiags-n-INFO",  qp.."iF", "All buffer diagnostics only info"..n,        function() ed.diags_to_list({ filter = "only", level = vim.diagnostic.severity.INFO }, new_qflist()) end },
    { nn, pqfr.. "Qdiags-n-WARN",  qp.."iW", "All buffer diagnostics only warn"..n,        function() ed.diags_to_list({ filter = "only", level = vim.diagnostic.severity.WARN }, new_qflist()) end },
    { nn, pqfr.. "Qdiags-n-ERROR", qp.."iE", "All buffer diagnostics only error"..n,       function() ed.diags_to_list({ filter = "only", level = vim.diagnostic.severity.ERROR }, new_qflist()) end },

    { nn, pqfr.. "Ldiags-n-HINT",  lp.."iN", "Cur buf diagnostics only hint"..n,           function() ed.diags_to_list({ filter = "only", level = vim.diagnostic.severity.HINT }, new_loclist()) end },
    { nn, pqfr.. "Ldiags-n-INFO",  lp.."iF", "Cur buf diagnostics only info"..n,           function() ed.diags_to_list({ filter = "only", level = vim.diagnostic.severity.INFO }, new_loclist()) end },
    { nn, pqfr.. "Ldiags-n-WARN",  lp.."iW", "Cur buf diagnostics only warn"..n,           function() ed.diags_to_list({ filter = "only", level = vim.diagnostic.severity.WARN }, new_loclist()) end },
    { nn, pqfr.. "Ldiags-n-ERROR", lp.."iE", "Cur buf diagnostics only error"..n,          function() ed.diags_to_list({ filter = "only", level = vim.diagnostic.severity.ERROR }, new_loclist()) end },

    --------------
    --- FILTER ---
    --------------

    --- Cfilter ---

    { nx, pqfr.."-Qfilter-r-cfilter)",   qp.."kl",         "Qfilter cfilter"..r..sc,  function() ef.filter("cfilter", keep, in_vimsmart, replace_qflist()) end},
    { nx, pqfr.."-Qfilter!-r-cfilter)",  qp.."rl",         "Qfilter! cfilter"..r..sc, function() ef.filter("cfilter", nokeep, in_vimsmart, replace_qflist()) end},
    { nx, pqfr.."-Qfilter-r-CFILTER)",   qp.."kL",         "Qfilter cfilter"..r..cs,  function() ef.filter("cfilter", keep, in_sensitive, replace_qflist()) end},
    { nx, pqfr.."-Qfilter!-r-CFILTER)",  qp.."rL",         "Qfilter! cfilter"..r..cs, function() ef.filter("cfilter", nokeep, in_sensitive, replace_qflist()) end},
    { nx, pqfr.."-Qfilter-r-cfilterX)",  qp.."k<C-l>",     "Qfilter cfilter"..r..rx,  function() ef.filter("cfilter", keep, in_regex, replace_qflist()) end},
    { nx, pqfr.."-Qfilter!-r-cfilterX)", qp.."r<C-l>",     "Qfilter! cfilter"..r..rx, function() ef.filter("cfilter", nokeep, in_regex, replace_qflist()) end},

    { nx, pqfr.."-Lfilter-r-cfilter)",   lp.."kl",         "Lfilter cfilter"..r..sc,  function() ef.filter("cfilter", keep, in_vimsmart, replace_loclist()) end},
    { nx, pqfr.."-Lfilter!-r-cfilter)",  lp.."rl",         "Lfilter! cfilter"..r..sc, function() ef.filter("cfilter", nokeep, in_vimsmart, replace_loclist()) end},
    { nx, pqfr.."-Lfilter-r-CFILTER)",   lp.."kL",         "Lfilter cfilter"..r..cs,  function() ef.filter("cfilter", keep, in_sensitive, replace_loclist()) end},
    { nx, pqfr.."-Lfilter!-r-CFILTER)",  lp.."rL",         "Lfilter! cfilter"..r..cs, function() ef.filter("cfilter", nokeep, in_sensitive, replace_loclist()) end},
    { nx, pqfr.."-Lfilter-r-cfilterX)",  lp.."k<C-l>",     "Lfilter cfilter"..r..rx,  function() ef.filter("cfilter", keep, in_regex, replace_loclist()) end},
    { nx, pqfr.."-Lfilter!-r-cfilterX)", lp.."r<C-l>",     "Lfilter! cfilter"..r..rx, function() ef.filter("cfilter", nokeep, in_regex, replace_loclist()) end},

    --- Fname ---

    { nx, pqfr.."-Qfilter-r-fname)",     qp.."kf",         "Qfilter fname"..r..sc,    function() ef.filter("fname", keep, in_vimsmart, replace_qflist()) end},
    { nx, pqfr.."-Qfilter!-r-fname)",    qp.."rf",         "Qfilter! fname"..r..sc,   function() ef.filter("fname", nokeep, in_vimsmart, replace_qflist()) end},
    { nx, pqfr.."-Qfilter-r-FNAME)",     qp.."kF",         "Qfilter fname"..r..cs,    function() ef.filter("fname", keep, in_sensitive, replace_qflist()) end},
    { nx, pqfr.."-Qfilter!-r-FNAME)",    qp.."rF",         "Qfilter! fname"..r..cs,   function() ef.filter("fname", nokeep, in_sensitive, replace_qflist()) end},
    { nx, pqfr.."-Qfilter-r-fnameX)",    qp.."k<C-f>",     "Qfilter fname"..r..rx,    function() ef.filter("fname", keep, in_regex, replace_qflist()) end},
    { nx, pqfr.."-Qfilter!-r-fnameX)",   qp.."r<C-f>",     "Qfilter! fname"..r..rx,   function() ef.filter("fname", nokeep, in_regex, replace_qflist()) end},

    { nx, pqfr.."-Lfilter-r-fname)",     lp.."kf",         "Lfilter fname"..r..sc,    function() ef.filter("fname", keep, in_vimsmart, replace_loclist()) end},
    { nx, pqfr.."-Lfilter!-r-fname)",    lp.."rf",         "Lfilter! fname"..r..sc,   function() ef.filter("fname", nokeep, in_vimsmart, replace_loclist()) end},
    { nx, pqfr.."-Lfilter-r-FNAME)",     lp.."kF",         "Lfilter fname"..r..cs,    function() ef.filter("fname", keep, in_sensitive, replace_loclist()) end},
    { nx, pqfr.."-Lfilter!-r-FNAME)",    lp.."rF",         "Lfilter! fname"..r..cs,   function() ef.filter("fname", nokeep, in_sensitive, replace_loclist()) end},
    { nx, pqfr.."-Lfilter-r-fnameX)",    lp.."k<C-f>",     "Lfilter fname"..r..rx,    function() ef.filter("fname", keep, in_regex, replace_loclist()) end},
    { nx, pqfr.."-Lfilter!-r-fnameX)",   lp.."r<C-f>",     "Lfilter! fname"..r..rx,   function() ef.filter("fname", nokeep, in_regex, replace_loclist()) end},

    --- Text ---

    { nx, pqfr.."-Qfilter-r-text)",      qp.."ke",         "Qfilter text"..r..sc,     function() ef.filter("text", keep, in_vimsmart, replace_qflist()) end},
    { nx, pqfr.."-Qfilter!-r-text)",     qp.."re",         "Qfilter! text"..r..sc,    function() ef.filter("text", nokeep, in_vimsmart, replace_qflist()) end},
    { nx, pqfr.."-Qfilter-r-TEXT)",      qp.."kE",         "Qfilter text"..r..cs,     function() ef.filter("text", keep, in_sensitive, replace_qflist()) end},
    { nx, pqfr.."-Qfilter!-r-TEXT)",     qp.."rE",         "Qfilter! text"..r..cs,    function() ef.filter("text", nokeep, in_sensitive, replace_qflist()) end},
    { nx, pqfr.."-Qfilter-r-textX)",     qp.."k<C-e>",     "Qfilter text"..r..rx,     function() ef.filter("text", keep, in_regex, replace_qflist()) end},
    { nx, pqfr.."-Qfilter!-r-textX)",    qp.."r<C-e>",     "Qfilter! text"..r..rx,    function() ef.filter("text", nokeep, in_regex, replace_qflist()) end},

    { nx, pqfr.."-Lfilter-r-text)",      lp.."ke",         "Lfilter text"..r..sc,     function() ef.filter("text", keep, in_vimsmart, replace_loclist()) end},
    { nx, pqfr.."-Lfilter!-r-text)",     lp.."re",         "Lfilter! text"..r..sc,    function() ef.filter("text", nokeep, in_vimsmart, replace_loclist()) end},
    { nx, pqfr.."-Lfilter-r-TEXT)",      lp.."kE",         "Lfilter text"..r..cs,     function() ef.filter("text", keep, in_sensitive, replace_loclist()) end},
    { nx, pqfr.."-Lfilter!-r-TEXT)",     lp.."rE",         "Lfilter! text"..r..cs,    function() ef.filter("text", nokeep, in_sensitive, replace_loclist()) end},
    { nx, pqfr.."-Lfilter-r-textX)",     lp.."k<C-e>",     "Lfilter text"..r..rx,     function() ef.filter("text", keep, in_regex, replace_loclist()) end},
    { nx, pqfr.."-Lfilter!-r-textX)",    lp.."r<C-e>",     "Lfilter! text"..r..rx,    function() ef.filter("text", nokeep, in_regex, replace_loclist()) end},

    --- Lnum ---

    { nx, pqfr.."-Qfilter-r-lnum)",      qp.."kn",         "Qfilter lnum"..r..sc,     function() ef.filter("lnum", keep, in_vimsmart, replace_qflist()) end},
    { nx, pqfr.."-Qfilter!-r-lnum)",     qp.."rn",         "Qfilter! lnum"..r..sc,    function() ef.filter("lnum", nokeep, in_vimsmart, replace_qflist()) end},
    { nx, pqfr.."-Qfilter-r-LNUM)",      qp.."kN",         "Qfilter lnum"..r..cs,     function() ef.filter("lnum", keep, in_sensitive, replace_qflist()) end},
    { nx, pqfr.."-Qfilter!-r-LNUM)",     qp.."rN",         "Qfilter! lnum"..r..cs,    function() ef.filter("lnum", nokeep, in_sensitive, replace_qflist()) end},
    { nx, pqfr.."-Qfilter-r-lnumX)",     qp.."k<C-n>",     "Qfilter lnum"..r..rx,     function() ef.filter("lnum", keep, in_regex, replace_qflist()) end},
    { nx, pqfr.."-Qfilter!-r-lnumX)",    qp.."r<C-n>",     "Qfilter! lnum"..r..rx,    function() ef.filter("lnum", nokeep, in_regex, replace_qflist()) end},

    { nx, pqfr.."-Lfilter-r-lnum)",      lp.."kn",         "Lfilter lnum"..r..sc,     function() ef.filter("lnum", keep, in_vimsmart, replace_loclist()) end},
    { nx, pqfr.."-Lfilter!-r-lnum)",     lp.."rn",         "Lfilter! lnum"..r..sc,    function() ef.filter("lnum", nokeep, in_vimsmart, replace_loclist()) end},
    { nx, pqfr.."-Lfilter-r-LNUM)",      lp.."kN",         "Lfilter lnum"..r..cs,     function() ef.filter("lnum", keep, in_sensitive, replace_loclist()) end},
    { nx, pqfr.."-Lfilter!-r-LNUM)",     lp.."rN",         "Lfilter! lnum"..r..cs,    function() ef.filter("lnum", nokeep, in_sensitive, replace_loclist()) end},
    { nx, pqfr.."-Lfilter-r-lnumX)",     lp.."k<C-n>",     "Lfilter lnum"..r..rx,     function() ef.filter("lnum", keep, in_regex, replace_loclist()) end},
    { nx, pqfr.."-Lfilter!-r-lnumX)",    lp.."r<C-n>",     "Lfilter! lnum"..r..rx,    function() ef.filter("lnum", nokeep, in_regex, replace_loclist()) end},

    --- Type ---

    { nx, pqfr.."-Qfilter-r-type)",      qp.."kt",         "Qfilter type"..r..sc,     function() ef.filter("type", keep, in_vimsmart, replace_qflist()) end},
    { nx, pqfr.."-Qfilter!-r-type)",     qp.."rt",         "Qfilter! type"..r..sc,    function() ef.filter("type", nokeep, in_vimsmart, replace_qflist()) end},
    { nx, pqfr.."-Qfilter-r-TYPE)",      qp.."kT",         "Qfilter type"..r..cs,     function() ef.filter("type", keep, in_sensitive, replace_qflist()) end},
    { nx, pqfr.."-Qfilter!-r-TYPE)",     qp.."rT",         "Qfilter! type"..r..cs,    function() ef.filter("type", nokeep, in_sensitive, replace_qflist()) end},
    { nx, pqfr.."-Qfilter-r-typeX)",     qp.."k<C-t>",     "Qfilter type"..r..rx,     function() ef.filter("type", keep, in_regex, replace_qflist()) end},
    { nx, pqfr.."-Qfilter!-r-typeX)",    qp.."r<C-t>",     "Qfilter! type"..r..rx,    function() ef.filter("type", nokeep, in_regex, replace_qflist()) end},

    { nx, pqfr.."-Lfilter-r-type)",      lp.."kt",         "Lfilter type"..r..sc,     function() ef.filter("type", keep, in_vimsmart, replace_loclist()) end},
    { nx, pqfr.."-Lfilter!-r-type)",     lp.."rt",         "Lfilter! type"..r..sc,    function() ef.filter("type", nokeep, in_vimsmart, replace_loclist()) end},
    { nx, pqfr.."-Lfilter-r-TYPE)",      lp.."kT",         "Lfilter type"..r..cs,     function() ef.filter("type", keep, in_sensitive, replace_loclist()) end},
    { nx, pqfr.."-Lfilter!-r-TYPE)",     lp.."rT",         "Lfilter! type"..r..cs,    function() ef.filter("type", nokeep, in_sensitive, replace_loclist()) end},
    { nx, pqfr.."-Lfilter-r-typeX)",     lp.."k<C-t>",     "Lfilter type"..r..rx,     function() ef.filter("type", keep, in_regex, replace_loclist()) end},
    { nx, pqfr.."-Lfilter!-r-typeX)",    lp.."r<C-t>",     "Lfilter! type"..r..rx,    function() ef.filter("type", nokeep, in_regex, replace_loclist()) end},

    ------------
    --- GREP ---
    ------------

    { nx, pqfr.."-grep-n-cwd)",    qp.."gd",         "Qgrep cwd, new"..sc,           function() eg.grep("cwd", in_vimsmart, sys_opt, new_qflist()) end },
    { nx, pqfr.."-grep-n-CWD)",    qp.."gD",         "Qgrep cwd, new"..cs,           function() eg.grep("cwd", in_sensitive, sys_opt, new_qflist()) end },
    { nx, pqfr.."-grep-n-cwdX)",   qp.."g<C-d>",     "Qgrep cwd, new"..rx,           function() eg.grep("cwd", in_regex, sys_opt, new_qflist()) end },

    { nx, pqfr.."-lgrep-n-cwd)",   lp.."gd",         "Lgrep cwd, new"..sc,           function() eg.grep("cwd", in_vimsmart, sys_opt, new_loclist()) end },
    { nx, pqfr.."-lgrep-n-CWD)",   lp.."gD",         "Lgrep cwd, new"..cs,           function() eg.grep("cwd", in_sensitive, sys_opt, new_loclist()) end },
    { nx, pqfr.."-lgrep-n-cwdX)",  lp.."g<C-d>",     "Lgrep cwd, new"..rx,           function() eg.grep("cwd", in_regex, sys_opt, new_loclist()) end },

    { nx, pqfr.."-grep-n-help)",   qp.."gh",         "Qgrep docs, new"..sc,          function() eg.grep("help", in_vimsmart, sys_opt, new_qflist()) end },
    { nx, pqfr.."-grep-n-HELP)",   qp.."gH",         "Qgrep docs, new"..cs,          function() eg.grep("help", in_sensitive, sys_opt, new_qflist()) end },
    { nx, pqfr.."-grep-n-helpX)",  qp.."g<C-h>",     "Qgrep docs, new"..rx,          function() eg.grep("help", in_regex, sys_opt, new_qflist()) end },

    { nx, pqfr.."-lgrep-n-help)",  lp.."gh",         "Lgrep docs, new"..sc,          function() eg.grep("help", in_vimsmart, sys_opt, new_loclist()) end },
    { nx, pqfr.."-lgrep-n-HELP)",  lp.."gH",         "Lgrep docs, new"..cs,          function() eg.grep("help", in_sensitive, sys_opt, new_loclist()) end },
    { nx, pqfr.."-lgrep-n-helpX)", lp.."g<C-h>",     "Lgrep docs, new"..rx,          function() eg.grep("help", in_regex, sys_opt, new_loclist()) end },

    { nx, pqfr.."-grep-n-bufs)",   qp.."gu",         "Qgrep open bufs, new"..sc,     function() eg.grep("bufs", in_vimsmart, sys_opt, new_qflist()) end },
    { nx, pqfr.."-grep-n-BUFS)",   qp.."gU",         "Qgrep open bufs, new"..cs,     function() eg.grep("bufs", in_sensitive, sys_opt, new_qflist()) end },
    { nx, pqfr.."-grep-n-bufsX)",  qp.."g<C-u>",     "Qgrep open bufs, new"..rx,     function() eg.grep("bufs", in_regex, sys_opt, new_qflist()) end },

    { nx, pqfr.."-lgrep-n-cbuf)",  lp.."gu",         "Lgrep cur buf, new"..sc,       function() eg.grep("cbuf", in_vimsmart, sys_opt, new_loclist()) end },
    { nx, pqfr.."-lgrep-n-CBUF)",  lp.."gU",         "Lgrep cur buf, new"..cs,       function() eg.grep("cbuf", in_sensitive, sys_opt, new_loclist()) end },
    { nx, pqfr.."-lgrep-n-cbufX)", lp.."g<C-u>",     "Lgrep cur buf, new"..rx,       function() eg.grep("cbuf", in_regex, sys_opt, new_loclist()) end },

    -------------------------
    --- OPEN/CLOSE/RESIZE ---
    -------------------------

    { nn, pqfr.."-open-qf-list)",     qp.."p", "Open the quickfix list",               function() eo._open_qflist({ always_resize = true, height = vim.v.count, print_errs = true }) end },
    { nn, pqfr.."-open-qf-list-max)", qp.."P", "Open the quickfix list to max height", function() eo._open_qflist({ always_resize = true, height = QFR_MAX_HEIGHT, print_errs = true }) end },
    { nn, pqfr.."-close-qf-list)",    qp.."o", "Close the quickfix list",              function() eo._close_qflist() end },
    { nn, pqfr.."-toggle-qf-list)",   qp.."q", "Toggle the quickfix list",             function() eo._toggle_qflist()  end },
    { nn, pqfr.."-open-loclist)",     lp.."p", "Open the location list",               function() eo._open_loclist(cur_win(), { always_resize = true, height = vim.v.count, print_errs = true }) end },
    { nn, pqfr.."-open-loclist-max)", lp.."P", "Open the location list to max height", function() eo._open_loclist(cur_win(), { always_resize = true, height = QFR_MAX_HEIGHT, print_errs = true }) end },
    { nn, pqfr.."-close-loclist)",    lp.."o", "Close the location list",              function() eo._close_loclist(cur_win()) end },
    { nn, pqfr.."-toggle-loclist)",   lp.."l", "Toggle the location list",             function() eo._toggle_loclist(cur_win()) end },

    ------------------
    --- NAVIGATION ---
    ------------------

    { nn, pqfr.."-qf-prev)",  "[q",          "Go to a previous qf entry",       function() en._q_prev(vim.v.count, {}) end },
    { nn, pqfr.."-qf-next)",  "]q",          "Go to a later qf entry",          function() en._q_next(vim.v.count, {}) end },
    { nn, pqfr.."-qf-rewind)","[Q",          "Go to the first qf entry",        function() en._q_rewind(vim.v.count) end },
    { nn, pqfr.."-qf-last)",  "]Q",          "Go to the last qf entry",         function() en._q_last(vim.v.count) end },
    { nn, pqfr.."-qf-pfile)", "[<C-q>",      "Go to the previous qf file",      function() en._q_pfile(vim.v.count) end },
    { nn, pqfr.."-qf-nfile)", "]<C-q>",      "Go to the next qf file",          function() en._q_nfile(vim.v.count) end },
    { nn, pqfr.."-ll-prev)",  "[l",          "Go to a previous loclist entry",  function() en._l_prev(cur_win(), vim.v.count, {}) end },
    { nn, pqfr.."-ll-next)",  "]l",          "Go to a later loclist entry",     function() en._l_next(cur_win(), vim.v.count, {}) end },
    { nn, pqfr.."-ll-rewind)","[L",          "Go to the first loclist entry",   function() en._l_rewind(cur_win(), vim.v.count) end },
    { nn, pqfr.."-ll-last)",  "]L",          "Go to the last loclist entry",    function() en._l_last(cur_win(), vim.v.count) end },
    { nn, pqfr.."-ll-pfile)", "[<C-l>",      "Go to the previous loclist file", function() en._l_pfile(cur_win(), vim.v.count) end },
    { nn, pqfr.."-ll-nfile)", "]<C-l>",      "Go to the next loclist file",     function() en._l_nfile(cur_win(), vim.v.count) end },

    ------------
    --- SORT ---
    ------------

    --- DOCUMENT: This breaks the usual pattern by simply replacing the list
    --- LOW: Keeping the mappings simple here so we're just sorting in place. If use cases come up
    --- where adding and replacing lists is necessary, can unlock those maps
    { nn, pqfr.."-qsort-r-fname-asc)",       qp.."tf",  "Qsort by fname asc"..r,           function() es.sort("fname", { dir = "asc" }, replace_qflist()) end },
    { nn, pqfr.."-qsort-r-fname-desc)",      qp.."tF",  "Qsort by fname desc"..r,          function() es.sort("fname", { dir = "desc" }, replace_qflist()) end },
    { nn, pqfr.."-qsort-r-fname-diag-asc)",  qp.."tif", "Qsort by fname_diag asc"..r,      function() es.sort("fname_diag", { dir = "asc" }, replace_qflist()) end },
    { nn, pqfr.."-qsort-r-fname-diag-desc)", qp.."tiF", "Qsort by fname_diag desc"..r,     function() es.sort("fname_diag", { dir = "desc" }, replace_qflist()) end },
    { nn, pqfr.."-qsort-r-severity-asc)",    qp.."tis", "Qsort by severity asc"..r,        function() es.sort("severity", { dir = "asc" }, replace_qflist()) end },
    { nn, pqfr.."-qsort-r-severity-desc)",   qp.."tiS", "Qsort by severity desc"..r,       function() es.sort("severity", { dir = "desc" }, replace_qflist()) end },
    { nn, pqfr.."-qsort-r-type-asc)",        qp.."tt",  "Qsort by type asc"..r,            function() es.sort("type", { dir = "asc" }, replace_qflist()) end },
    { nn, pqfr.."-qsort-r-type-desc)",       qp.."tT",  "Qsort by type desc"..r,           function() es.sort("type", { dir = "desc" }, replace_qflist()) end },

    { nn, pqfr.."-lsort-r-fname-asc)",       lp.."tf",  "Lsort by fname asc"..r,           function() es.sort("fname", { dir = "asc" }, replace_loclist()) end },
    { nn, pqfr.."-lsort-r-fname-desc)",      lp.."tF",  "Lsort by fname desc"..r,          function() es.sort("fname", { dir = "desc" }, replace_loclist()) end },
    { nn, pqfr.."-lsort-r-fname-diag-asc)",  lp.."tif", "Lsort by fname_diag asc"..r,      function() es.sort("fname_diag", { dir = "asc" }, replace_loclist()) end },
    { nn, pqfr.."-lsort-r-fname-diag-desc)", lp.."tiF", "Lsort by fname_diag desc"..r,     function() es.sort("fname_diag", { dir = "desc" }, replace_loclist()) end },
    { nn, pqfr.."-lsort-r-severity-asc)",    lp.."tis", "Lsort by severity asc"..r,        function() es.sort("severity", { dir = "asc" }, replace_loclist()) end },
    { nn, pqfr.."-lsort-r-severity-desc)",   lp.."tiS", "Lsort by severity desc"..r,       function() es.sort("severity", { dir = "desc" }, replace_loclist()) end },
    { nn, pqfr.."-lsort-r-type-asc)",        lp.."tt",  "Lsort by type asc"..r,            function() es.sort("type", { dir = "asc" }, replace_loclist()) end },
    { nn, pqfr.."-lsort-r-type-desc)",       lp.."tT",  "Lsort by type desc"..r,           function() es.sort("type", { dir = "desc" }, replace_loclist()) end },


    -------------
    --- STACK ---
    -------------

    --- DOCUMENT: older/newer are meant for cycling. so 2<leader>q[ will go back two lists
    --- The history commands are meant for targeting specific lists. So 2<leader>qQ will go to
    --- list two
    --- NOTE: For history, the open command is the more cumbersome map of the two. This is to
    --- align with the default behavior, where history only changes the list_nr, but does not
    --- open. If, in field testing, there are more cases where we want to open the list than
    --- just change, this can be swapped

    { nn, pqfr.."-qf-older)",        qp.."[", "Go to an older qflist",                         function() ea._q_older(vim.v.count) end },
    { nn, pqfr.."-qf-newer)",        qp.."]", "Go to a newer qflist",                          function() ea._q_newer(vim.v.count) end },
    { nn, pqfr.."-qf-history)",      qp.."Q", "View or jump within the quickfix history",      function() ea._q_history(vim.v.count, { default = "current" }) end },
    { nn, pqfr.."-qf-history-open)", qp.."<C-q>", "Open and jump within the quickfix history", function() ea._q_history(vim.v.count, { always_open = true, default = "current" }) end },
    { nn, pqfr.."-qf-del)",          qp.."e", "Delete a list from the quickfix stack",         function() ea._q_del(vim.v.count) end },
    { nn, pqfr.."-qf-del-all)",      qp.."E", "Delete all items from the quickfix stack",      function() ea._q_del_all() end },
    { nn, pqfr.."-ll-older)",        lp.."[", "Go to an older location list",                  function() ea._l_older(cur_win(), vim.v.count) end },
    { nn, pqfr.."-ll-newer)",        lp.."]", "Go to a newer location list",                   function() ea._l_newer(cur_win(), vim.v.count) end },
    { nn, pqfr.."-ll-history)",      lp.."L", "View or jump within the loclist history",       function() ea._l_history(cur_win(), vim.v.count, { default = "current" }) end },
    { nn, pqfr.."-ll-history-open)", lp.."<C-l>", "Open and jump within the loclist history",  function() ea._l_history(cur_win(), vim.v.count, { always_open = true, default = "current" }) end },
    { nn, pqfr.."-ll-del)",          lp.."e", "Delete a list from the loclist stack",          function() ea._l_del(cur_win(), vim.v.count) end },
    { nn, pqfr.."-ll-del-all)",      lp.."E", "Delete all items from the loclist stack",       function() ea._l_del_all(cur_win()) end },
}

--- NOTE: This table needs to be separate or else the plug mapping pass will map "<nop>", which
--- causes multiple problems

-- stylua: ignore
---@type QfRancherMapData[]
local rancher_keymap_default_rm = {
    { nx, "<nop>", "<leader>q", "Avoid falling back to defaults", nil },
    { nx, "<nop>", "<leader>l", "Avoid falling back to defaults", nil },

    -------------------
    --- DIAGNOSTICS ---
    -------------------

    { nx, "<nop>", "<leader>qi",     "Avoid falling back to defaults", nil },
    { nx, "<nop>", "<leader>qI",     "Avoid falling back to defaults", nil },
    { nx, "<nop>", "<leader>q<C-i>", "Avoid falling back to defaults", nil },
    { nx, "<nop>", "<leader>li",     "Avoid falling back to defaults", nil },
    { nx, "<nop>", "<leader>lI",     "Avoid falling back to defaults", nil },
    { nx, "<nop>", "<leader>l<C-i>", "Avoid falling back to defaults", nil },

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

    ------------
    --- GREP ---
    ------------

    { nx, "<nop>", "<leader>qg",     "Avoid falling back to defaults", nil },
    { nx, "<nop>", "<leader>qG",     "Avoid falling back to defaults", nil },
    { nx, "<nop>", "<leader>q<c-g>", "Avoid falling back to defaults", nil },
    { nx, "<nop>", "<leader>lg",     "Avoid falling back to defaults", nil },
    { nx, "<nop>", "<leader>lG",     "Avoid falling back to defaults", nil },
    { nx, "<nop>", "<leader>l<c-g>", "Avoid falling back to defaults", nil },

    ------------
    --- SORT ---
    ------------

    { nn, "<nop>", "<leader>qt",     "Avoid falling back to defaults", nil },
    { nn, "<nop>", "<leader>qT",     "Avoid falling back to defaults", nil },
    { nn, "<nop>", "<leader>q<C-t>", "Avoid falling back to defaults", nil },
    { nn, "<nop>", "<leader>lt",     "Avoid falling back to defaults", nil },
    { nn, "<nop>", "<leader>lT",     "Avoid falling back to defaults", nil },
    { nn, "<nop>", "<leader>l<C-t>", "Avoid falling back to defaults", nil },
}

for _, map in ipairs(rancher_keymaps) do
    for _, mode in ipairs(map[1]) do
        api.nvim_set_keymap(mode, map[2], "", {
            callback = map[5],
            desc = map[4],
            noremap = true,
        })
    end
end

-- Don't use the util g_var wrapper here to avoid a require
if vim.g.qf_rancher_set_default_maps then
    for _, map in ipairs(rancher_keymaps) do
        for _, mode in ipairs(map[1]) do
            api.nvim_set_keymap(mode, map[3], map[2], {
                desc = map[4],
                noremap = true,
            })
        end
    end

    for _, map in ipairs(rancher_keymap_default_rm) do
        for _, mode in ipairs(map[1]) do
            api.nvim_set_keymap(mode, map[3], map[2], {
                desc = map[4],
                noremap = true,
            })
        end
    end
end

---------------------
--- FTPLUGIN MAPS ---
---------------------

vim.keymap.set("n", pqfr .. "-list-del-one)", function()
    ei._del_one_list_item()
end, { desc = "Delete the current list line" })

vim.keymap.set("x", pqfr .. "-list-visual-del)", function()
    ei._visual_del()
end, { desc = "Delete a visual line selection" })

vim.keymap.set("n", pqfr .. "-list-toggle-preview)", function()
    ep.toggle_preview_win(api.nvim_get_current_win())
end, { desc = "Toggle the preview win" })

vim.keymap.set("n", pqfr .. "-list-update-preview-pos)", function()
    ep.update_preview_win_pos()
end, { desc = "Update the preview win position" })

vim.keymap.set("n", pqfr .. "-list-open-direct-focuswin)", function()
    ei._open_direct_focuswin()
end, { desc = "Open a list item and focus on it" })

vim.keymap.set("n", pqfr .. "-list-open-direct-focuslist)", function()
    ei._open_direct_focuslist()
end, { desc = "Open a list item, keep list focus" })

vim.keymap.set("n", pqfr .. "-list-prev)", function()
    ei._open_prev_focuslist()
end, { desc = "Go to a previous qf entry, keep window focus" })

vim.keymap.set("n", pqfr .. "-list-next)", function()
    ei._open_next_focuslist()
end, { desc = "Go to a later qf entry, keep window focus" })

vim.keymap.set("n", pqfr .. "-list-open-split-focuswin)", function()
    ei._open_split_focuswin()
end, { desc = "Open a list item in a split and focus on it" })

vim.keymap.set("n", pqfr .. "-list-open-split-focuslist)", function()
    ei._open_split_focuslist()
end, { desc = "Open a list item in a split, keep list focus" })

vim.keymap.set("n", pqfr .. "-list-open-vsplit-focuswin)", function()
    ei._open_vsplit_focuswin()
end, { desc = "Open a list item in a vsplit and focus on it" })

vim.keymap.set("n", pqfr .. "-list-open-vsplit-focuslist)", function()
    ei._open_vsplit_focuslist()
end, { desc = "Open a list item in a vsplit, keep list focus" })

vim.keymap.set("n", pqfr .. "-list-open-tabnew-focuswin)", function()
    ei._open_tabnew_focuswin()
end, { desc = "Open a list item in a new tab and focus on it" })

vim.keymap.set("n", pqfr .. "-list-open-tabnew-focuslist)", function()
    ei._open_tabnew_focuslist()
end, { desc = "Open a list item in a new tab, keep list focus" })

------------
--- CMDS ---
------------

-- Don't use the util g_var wrapper here to avoid a require
if vim.g.qf_rancher_set_default_cmds then
    -------------
    --- DIAGS ---
    -------------

    api.nvim_create_user_command("Qdiag", function(cargs)
        ed.q_diag_cmd(cargs)
    end, { count = 0, nargs = "*", desc = "Get all diagnostics for the Quickfix list" })

    api.nvim_create_user_command("Ldiag", function(cargs)
        ed.l_diag_cmd(cargs)
    end, { count = 0, nargs = "*", desc = "Get current buf diagnostics for the Location list" })

    --------------
    --- FILTER ---
    --------------

    api.nvim_create_user_command("Qfilter", function(cargs)
        ef.q_filter_cmd(cargs)
    end, { bang = true, count = true, nargs = "*", desc = "Sort quickfix items" })

    api.nvim_create_user_command("Lfilter", function(cargs)
        ef.l_filter_cmd(cargs)
    end, { bang = true, count = true, nargs = "*", desc = "Sort loclist items" })

    --------------
    --- GREP ---
    --------------

    api.nvim_create_user_command("Qgrep", function(cargs)
        eg.q_grep_cmd(cargs)
    end, { count = true, nargs = "*", desc = "Grep to the quickfix list" })

    api.nvim_create_user_command("Lgrep", function(cargs)
        eg.l_grep_cmd(cargs)
    end, { count = true, nargs = "*", desc = "Grep to the location list" })

    -------------------------
    --- OPEN/CLOSE/TOGGLE ---
    -------------------------

    --- NOTE: If actual opts or logic are added to the close/toggle cmds, put that in the open
    --- module and call an exposed funtion here

    api.nvim_create_user_command("Qopen", function(cargs)
        eo._open_qflist_cmd(cargs)
    end, { count = 0, desc = "Open the Quickfix list" })

    api.nvim_create_user_command("Lopen", function(cargs)
        eo._open_loclist_cmd(cargs)
    end, { count = 0, desc = "Open the Location List" })

    api.nvim_create_user_command("Qclose", function()
        eo._close_qflist()
    end, { desc = "Close the Quickfix list" })

    -- TODO: Bring all these into the open file
    api.nvim_create_user_command("Lclose", function()
        eo._close_loclist(api.nvim_get_current_win())
    end, { desc = "Close the Location List" })

    api.nvim_create_user_command("Qtoggle", function()
        eo._toggle_qflist()
    end, { desc = "Toggle the Quickfix list" })

    api.nvim_create_user_command("Ltoggle", function()
        eo._toggle_loclist(api.nvim_get_current_win())
    end, { desc = "Toggle the Location List" })

    ------------------
    --- NAV/ACTION ---
    ------------------

    api.nvim_create_user_command("Qprev", function(cargs)
        en._q_prev_cmd(cargs)
    end, { count = 0, desc = "Go to a previous qf entry" })

    api.nvim_create_user_command("Qnext", function(cargs)
        en._q_next_cmd(cargs)
    end, { count = 0, desc = "Go to a later qf entry" })

    api.nvim_create_user_command("Qrewind", function(cargs)
        en._q_rewind_cmd(cargs)
    end, { count = 0, desc = "Go to the first or count qf entry" })

    api.nvim_create_user_command("Qlast", function(cargs)
        en._q_last_cmd(cargs)
    end, { count = 0, desc = "Go to the last or count qf entry" })

    api.nvim_create_user_command("Qq", function(cargs)
        en._q_q_cmd(cargs)
    end, { count = 0, desc = "Go to the current qf entry" })

    api.nvim_create_user_command("Qpfile", function(cargs)
        en._q_pfile_cmd(cargs)
    end, { count = 0, desc = "Go to the previous qf file" })

    api.nvim_create_user_command("Qnfile", function(cargs)
        en._q_nfile_cmd(cargs)
    end, { count = 0, desc = "Go to the next qf file" })

    api.nvim_create_user_command("Lprev", function(cargs)
        en._l_prev_cmd(cargs)
    end, { count = 0, desc = "Go to a previous loclist entry" })

    api.nvim_create_user_command("Lnext", function(cargs)
        en._l_next_cmd(cargs)
    end, { count = 0, desc = "Go to a later loclist entry" })

    api.nvim_create_user_command("Lrewind", function(cargs)
        en._l_rewind_cmd(cargs)
    end, { count = 0, desc = "Go to the first or count loclist entry" })

    api.nvim_create_user_command("Llast", function(cargs)
        en._l_last_cmd(cargs)
    end, { count = 0, desc = "Go to the last or count loclist entry" })

    api.nvim_create_user_command("Ll", function(cargs)
        en._l_l_cmd(cargs)
    end, { count = 0, desc = "Go to the current loclist entry" })

    api.nvim_create_user_command("Lpfile", function(cargs)
        en._l_pfile_cmd(cargs)
    end, { count = 0, desc = "Go to the previous loclist file" })

    api.nvim_create_user_command("Lnfile", function(cargs)
        en._l_nfile_cmd(cargs)
    end, { count = 0, desc = "Go to the next loclist file" })

    ------------
    --- SORT ---
    ------------

    api.nvim_create_user_command("Qsort", function(cargs)
        es.q_sort(cargs)
    end, { nargs = "*" })

    api.nvim_create_user_command("Lsort", function(cargs)
        es.l_sort(cargs)
    end, { nargs = "*" })

    -------------
    --- STACK ---
    -------------

    api.nvim_create_user_command("Qolder", function(cargs)
        ea._q_older_cmd(cargs)
    end, { count = 0, desc = "Go to an older qflist" })

    api.nvim_create_user_command("Qnewer", function(cargs)
        ea._q_newer_cmd(cargs)
    end, { count = 0, desc = "Go to a newer qflist" })

    api.nvim_create_user_command("Qhistory", function(cargs)
        ea._q_history_cmd(cargs)
    end, { count = 0, desc = "View or jump within the quickfix history" })

    api.nvim_create_user_command("Qdelete", function(cargs)
        ea._q_delete_cmd(cargs)
    end, { count = 0, nargs = "?", desc = "Delete one or all lists from the quickfix stack" })

    api.nvim_create_user_command("Lolder", function(cargs)
        ea._l_older_cmd(cargs)
    end, { count = 0, desc = "Go to an older location list" })

    api.nvim_create_user_command("Lnewer", function(cargs)
        ea._l_newer_cmd(cargs)
    end, { count = 0, desc = "Go to a newer location list" })

    api.nvim_create_user_command("Lhistory", function(cargs)
        ea._l_history_cmd(cargs)
    end, { count = 0, desc = "View or jump within the loclist history" })

    api.nvim_create_user_command("Ldelete", function(cargs)
        ea._l_delete_cmd(cargs)
    end, { count = 0, nargs = "?", desc = "Delete one or all lists from the loclist stack" })
end
