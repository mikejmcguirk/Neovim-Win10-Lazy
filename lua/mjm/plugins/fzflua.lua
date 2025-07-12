return {
    "ibhagwan/fzf-lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {},
    config = function()
        -- FUTURE: Turn :let g: into a picker

        local fzf_lua = require("fzf-lua")
        fzf_lua.setup({
            "telescope",
            winopts = {
                border = Border,
                preview = {
                    border = Border,
                },
            },
            keymap = {
                fzf = {
                    ["ctrl-s"] = "unix-line-discard",
                },
            },
            hls = {
                normal = "NormalFloat",
                preview_normal = "NormalFloat",
                border = "FloatBorder",
                preview_border = "FloatBorder",
                backdrop = "NormalFloat",
            },
        })

        vim.api.nvim_set_hl(0, "FzfLuaScrollBorderFull", { link = "FzfLuaScrollFloatFull" })
        vim.api.nvim_set_hl(0, "FzfLuaScrollFloatEmpty", { link = "FzfLuaScrollFloatFull" })
        vim.api.nvim_set_hl(0, "FzfLuaScrollBorderEmpty", { link = "FzfLuaScrollFloatFull" })
        vim.api.nvim_set_hl(0, "FzfLuaBufFlagCur", { link = "Constant" })
        vim.api.nvim_set_hl(0, "FzfLuaHeaderText", { link = "Constant" })

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

        -- TODO: Re-add this back in
        -- vim.keymap.set("n", "<leader>tl", function()
        --     builtin.grep_string({
        --         prompt_title = "Help",
        --         search = "",
        --         search_dirs = vim.api.nvim_get_runtime_file("doc/*.txt", true),
        --         only_sort_text = true,
        --     })
        -- end)
    end,
}
