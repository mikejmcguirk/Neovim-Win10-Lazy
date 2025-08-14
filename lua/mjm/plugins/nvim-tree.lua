local function setup_nvim_tree()
    require("nvim-tree").setup({
        disable_netrw = true,
        hijack_netrw = true,
        sort_by = "case_sensitive",
        view = {
            width = 36,
            number = true,
            relativenumber = true,
        },
        filters = {
            git_ignored = false,
        },
        diagnostics = {
            enable = true,
        },
        notify = {
            threshold = vim.log.levels.WARN,
            absolute_path = true,
        },
        on_attach = function(bufnr)
            local api = require("nvim-tree.api")

            api.config.mappings.default_on_attach(bufnr)
            vim.keymap.del("n", "<2-LeftMouse>", { buffer = bufnr })
            vim.keymap.del("n", "<2-RightMouse>", { buffer = bufnr })
            vim.keymap.set("n", "y", "<nop>", { buffer = bufnr })
        end,
    })
end

local cmds = {
    { "n", "<leader>nn", "NvimTreeToggle" },
    { "n", "<leader>nf", "NvimTreeFocus" },
    { "n", "<leader>ni", "NvimTreeFindFile" },
    { "n", "<leader>no", "NvimTreeOpen" },
    { "n", "<leader>nc", "NvimTreeClose" },
}

-- MAYBE: Had seen inconsistent issue with the initial keymap failing to run the lazy load
-- Hoping to not see that recur with new method
for _, c in pairs(cmds) do
    vim.keymap.set(c[1], c[2], "<cmd>" .. c[3] .. "<cr>")

    vim.api.nvim_create_user_command(c[3], function()
        for _, m in pairs(cmds) do
            vim.api.nvim_del_user_command(m[3])
        end

        require("mjm.pack").post_load("nvim-tree.lua")
        setup_nvim_tree()
        vim.cmd(c[3])
    end, {})
end
