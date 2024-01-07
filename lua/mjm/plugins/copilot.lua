return {
    "github/copilot.vim",
    event = { "BufReadPre", "BufNewFile" },
    init = function()
        if Env_Disable_Copilot == "true" then
            vim.g.copilot_enabled = false

            return
        end

        if Env_Copilot_Node then
            vim.g.copilot_node_command = Env_Copilot_Node
        else
            vim.api.nvim_err_writeln("NvimCopilotNode system variable not set")
        end

        vim.g.copilot_filetypes = {
            text = false,
        }

        vim.g.copilot_no_tab_map = true

        vim.keymap.set("i", "<C-l>", 'copilot#Accept("")', {
            expr = true,
            replace_keycodes = false,
        })
    end,
}
