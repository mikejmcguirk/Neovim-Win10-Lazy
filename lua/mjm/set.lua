---------------------------------
-- Disable netrw for nvim-tree --
---------------------------------

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_netrwSettings = 1

--------------------
-- Map Leader Key --
--------------------

vim.keymap.set("", "<Space>", "<Nop>", { noremap = true, silent = true })
vim.g.mapleader = " "
vim.g.maplocaleader = " "

------------------------------------
-- Line Numbering & Column Widths --
------------------------------------

vim.opt.nu = true
vim.opt.relativenumber = true
vim.opt.numberwidth = 5

vim.opt.signcolumn = "yes:1"

vim.opt.colorcolumn = "100"

vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.shiftround = true

--------------------------
-- Configure CursorLine --
--------------------------

vim.opt.cursorline = true

local cursorLineGroup = vim.api.nvim_create_augroup("CursorLineControl", { clear = true })
local set_cursorline = function(event, value, pattern)
    vim.api.nvim_create_autocmd(event, {
        group = cursorLineGroup,
        pattern = pattern,
        callback = function()
            vim.opt_local.cursorline = value
        end,
    })
end

set_cursorline("WinLeave", false)
set_cursorline("WinEnter", true)
set_cursorline("FileType", false, "TelescopePrompt")

----------------
-- Aesthetics --
----------------

vim.opt.termguicolors = true

vim.cmd([[set gcr=n:block-blinkon1,i-c:ver100-blinkon1,v-r:hor100-blinkon1]])

vim.opt.scrolloff = 6

vim.wo.wrap = false
vim.opt.wrap = false

vim.opt.splitright = true

vim.opt.showmode = false

------------
-- Search --
------------

vim.opt.hlsearch = true
vim.opt.incsearch = true

vim.opt.ignorecase = true
vim.opt.smartcase = true

-------------------------
-- Misc. Functionality --
-------------------------

vim.opt.autoindent = true
vim.opt.cindent = true

vim.opt.updatetime = 1000

-----------------
-- Quick-scope --
-----------------

vim.g.qs_highlight_on_keys = { "f", "F", "t", "T" }
vim.g.qs_max_chars = 510

---------
-- ALE --
---------

vim.g.ale_linters_explicit = 1
vim.g.ale_javascript_prettier_use_local_config = 1

----------------
-- Formatting --
----------------

-- Relies on the rust.vim plugin, which calls the RustFmt installed by rustup
vim.g.rustfmt_autosave = 0
-- If disabled, RustFmt will publish failures to the location list
vim.g.rustfmt_fail_silently = 1

-------------
-- Copilot --
-------------

local copilotNode = os.getenv("NvimCopilotNode")


if os.getenv("DisableCopilot") == "true" then
    vim.g.copilot_enabled = false
else
    if copilotNode then
        vim.g.copilot_node_command = copilotNode
    else
        print(
            "NvimCopilotNode system variable not set. " ..
            "Node 16.15.0 is the highest supported version. " ..
            "Default Node path will be used if it exists")
    end
end

---------------
-- Maximizer --
---------------

vim.g.maximizer_set_default_mapping = 0
vim.g.maximizer_set_mapping_with_bang = 0

--------------
-- Undotree --
--------------

local winHome = os.getenv("USERPROFILE")
local winNvimDataPath = "\\AppData\\Local\\nvim-data\\undodir"
local isWin = vim.fn.has("win32")

if winHome and winNvimDataPath and isWin == 1 then
    vim.opt.swapfile = false
    vim.opt.backup = false
    vim.opt.undofile = true
    vim.opt.undodir = winHome .. winNvimDataPath

    vim.g.undotree_SetFocusWhenToggle = 1
    vim.g.undotree_WindowLayout = 3
else
    print("Could not set undodir for undotree. Using Nvim defaults.")
    print("Debug Information:")
    print("  USERPROFILE env variable: " .. (winHome or "Not set"))
    print("  Nvim Data Path: " .. (winNvimDataPath or "Not set"))
    print("  Is Windows: " .. (isWin == 1 and "True" or "False"))
end

----------------------
-- Markdown Preview --
----------------------

vim.g.mkdp_auto_start = 0
vim.g.mkdp_auto_close = 0

-- When set to one, only refreshes on save or leaving insert mode
vim.g.mkdp_refresh_slow = 0

-- When set to 1, MD Preview can be used on any file type instead of just markdown
vim.g.mkdp_command_for_global = 0

-- When set to 1, the preview server will be available to others on your network
-- Set to 0, and the server only listens to localhost
vim.g.mkdp_open_to_the_world = 0

-- For more detail: https://github.com/iamcco/markdown-preview.nvim/pull/9
vim.g.mkdp_open_ip = ""

local mainBrowser = os.getenv("MainBrowser")

if mainBrowser then
    vim.g.mkdp_browser = mainBrowser
else
    print("BrowserPath system variable not set. Default browser will be used if it exists")
end

vim.g.mkdp_echo_preview_url = 0

vim.g.mkdp_browserfunc = ""

vim.g.mkdp_preview_options = {
    mkit = {},
    katex = {},
    uml = {},
    maid = {},
    disable_sync_scroll = 0,
    sync_scroll_type = "middle", -- Where in the browser page your vim cursor will be
    hide_yaml_meta = 1,
    sequence_diagrams = {},
    flowchart_diagrams = {},
    content_editable = false, -- Edit content on preview page?
    disable_filename = 0,     -- Affects preview page
    toc = {}
}

-- Specify file path for custom markdown CSS
vim.g.mkdp_markdown_css = ""

-- File path for custom highlight CSS
vim.g.mkdp_highlight_css = ""

-- Specify which port to start the server on. Random otherwise
vim.g.mkdp_port = ""

-- Preview page title
vim.g.mkdp_page_title = "「${name}」" -- This setting uses the file name

vim.g.mkdp_filetypes = { "markdown" }

vim.g.mkdp_theme = "dark" -- Can be dark or light. Based on system preferences by default
