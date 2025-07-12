return {
    "ibhagwan/fzf-lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {},
    config = function()
        -- FUTURE: Turn :let g: into a picker
        -- How to see key help
        -- General note, put maps into config explicitly
        -- STILL NEEDED:
        --- Custom help search function. Though it looks possible thorugh inline customization
        --- Command history (not a huge deal though)
        --- Way to delete all text and start over
        -- AESTHETICS:
        --- error red is still in there. Replace with fluoro red
        -- HOW TO:
        --- Scroll previews

        local fzf_lua = require("fzf-lua")
        fzf_lua.setup({ "telescope" })
        -- fzf_lua.setup({
        --     winopts = {
        --         border = Border,
        --         preview = {
        --             border = Border,
        --             horizontal = "right:50%",
        --         },
        --     },
        --     fzf_colors = true,
        --     hls = {
        --         normal = "NormalFloat",
        --         preview_normal = "NormalFloat",
        --         border = "FloatBorder",
        --         preview_border = "FloatBorder",
        --         backdrop = "FloatBorder",
        --     },
        -- })

        -- vim.keymap.set("n", "<leader>tl", function()
        --     builtin.grep_string({
        --         prompt_title = "Help",
        --         search = "",
        --         search_dirs = vim.api.nvim_get_runtime_file("doc/*.txt", true),
        --         only_sort_text = true,
        --     })
        -- end)

        vim.keymap.set("n", "<leader>ff", fzf_lua.resume)

        vim.keymap.set("n", "<leader>fi", fzf_lua.files)
        vim.keymap.set("n", "<leader>fb", fzf_lua.buffers)
        vim.keymap.set("n", "<leader>fg", fzf_lua.git_files)

        vim.keymap.set("n", "<leader>fp", fzf_lua.grep)
        vim.keymap.set("n", "<leader>fe", fzf_lua.live_grep_glob)

        vim.keymap.set("n", "<leader>ft", fzf_lua.highlights)
        vim.keymap.set("n", "<leader>fr", fzf_lua.registers)
        vim.keymap.set("n", "<leader>fk", fzf_lua.keymaps)
        vim.keymap.set("n", "<leader>fu", fzf_lua.quickfix_stack)
        vim.keymap.set("n", "<leader>fo", fzf_lua.loclist_stack)
        vim.keymap.set("n", "<leader>fc", fzf_lua.command_history)

        vim.keymap.set("n", "<leader>fs", fzf_lua.spellcheck)
        vim.keymap.set("n", "<leader>fw", fzf_lua.lsp_live_workspace_symbols)
        vim.keymap.set("n", "<leader>fh", fzf_lua.helptags)
    end,
}
