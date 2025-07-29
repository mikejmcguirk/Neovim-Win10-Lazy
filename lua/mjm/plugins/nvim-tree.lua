local function setup_nvim_tree()
    require("nvim-tree").setup({
        disable_netrw = true,
        hijack_netrw = true,
        sort_by = "case_sensitive",
        view = {
            width = 36,
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
    { "n", "<leader>nn", "<cmd>NvimTreeToggle<cr>" },
    { "n", "<leader>nf", "<cmd>NvimTreeFocus<cr>" },
    { "n", "<leader>ni", "<cmd>NvimTreeFindFile<cr>" },
    { "n", "<leader>no", "<cmd>NvimTreeOpen<cr>" },
    { "n", "<leader>nc", "<cmd>NvimTreeClose<cr>" },
}

local function lazy_keymaps(setup_func, keymaps)
    local loaded = false

    for _, map in ipairs(keymaps) do
        local mode, lhs, rhs = unpack(map)
        vim.keymap.set(mode, lhs, function()
            if not loaded then
                setup_func()
                for _, inner_km in ipairs(keymaps) do
                    local inner_mode, inner_lhs, inner_rhs_str = unpack(inner_km)
                    vim.keymap.del(inner_mode, inner_lhs)
                    vim.keymap.set(inner_mode, inner_lhs, inner_rhs_str)
                end

                loaded = true
            end

            return rhs
        end, { expr = true })
    end
end

lazy_keymaps(setup_nvim_tree, cmds)
