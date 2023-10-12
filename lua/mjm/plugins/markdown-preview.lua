return {
    'iamcco/markdown-preview.nvim',
    ft = "markdown",
    config = function()
        vim.fn["mkdp#util#install"]()

        vim.keymap.set("n", "<leader>me", "<cmd>MarkdownPreview<cr>")
        vim.keymap.set("n", "<leader>ms", "<cmd>MarkdownPreviewStop<cr>")
        vim.keymap.set("n", "<leader>mt", "<cmd>MarkdownPreviewToggle<cr>")
    end,
    init = function()
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

        -- OS's default browser will be used if this is not set
        if Env_Main_Browser then
            vim.g.mkdp_browser = Env_Main_Browser
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
    end
}
