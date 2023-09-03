-- While building this config, I found that some settings did not load properly when they were
-- placed in the after folder. I think this is because of how lazy.nvim overrides the vim startup
-- sequence. Plugin settings that do not require their setup functions, therefore, are located here

-----------------
-- Quick-scope --
-----------------

vim.g.qs_highlight_on_keys = {"f", "F", "t", "T"}
vim.g.qs_max_chars = 205

---------
-- cmp --
---------

vim.opt.completeopt = {"menu", "menuone", "noselect"}

---------
-- LSP --
---------

vim.lsp.set_log_level("ERROR")
vim.g.lsp_log_verbose = 0

---------
-- ALE --
---------

vim.g.ale_linters_explicit = 1
vim.g.ale_javascript_prettier_use_local_config = 1

----------------
-- Formatting --
----------------

-- Relies on the rust.vim plugin, which calls the RustFmt installed by rustup
vim.g.rustfmt_autosave = 1
-- If disabled, RustFmt will publish failures to the location list
vim.g.rustfmt_fail_silently = 1

-------------
-- Copilot --
-------------

vim.g.copilot_node_command = "C:\\Users\\mikej\\AppData\\Roaming\\nvm\\v16.15.0\\node.exe"

--------------
-- Undotree --
--------------

vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undofile = true
vim.opt.undodir = "C:\\users\\mikej\\AppData\\Local\\nvim\\undodir"

vim.g.undotree_SetFocusWhenToggle = 1
vim.g.undotree_WindowLayout = 3

----------------------
-- Markdown Preview --
----------------------

vim.g.mkdp_auto_start = 0
vim.g.mkdp_auto_close = 0

-- When set to one, only refreshes on save or leaving insert mode
vim.g.mkdp_refresh_slow = 0

-- When set to 1, MD Preview can be used on any filetype instead of just markdown
vim.g.mkdp_command_for_global = 0

-- When set to 1, the preview server will be available to others on your network
-- Set to 0, and the server only listens to localhost
vim.g.mkdp_open_to_the_world = 0

-- For more detail: https://github.com/iamcco/markdown-preview.nvim/pull/9
vim.g.mkdp_open_ip = ""

vim.g.mkdp_browser =
    "C:\\Program Files\\BraveSoftware\\Brave-Browser\\Application\\brave.exe"

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
    disable_filename = 0, -- Affects preview page
    toc = {}
}

-- Specify filepath for custom markdown css
vim.g.mkdp_markdown_css = ""

-- Filepath for custom highlight css
vim.g.mkdp_highlight_css = ""

-- Specify which port to start the server on. Random otherwise
vim.g.mkdp_port = ""

-- Preview page title
vim.g.mkdp_page_title = "「${name}」" -- This setting uses the filename

vim.g.mkdp_filetypes = {"markdown"}

vim.g.mkdp_theme = "dark" -- Can be dark or light. Based on system preferences by default
