return {
    "mbbill/undotree",
    config = function()
        vim.keymap.set("n", "<leader>ut", "<cmd>UndotreeToggle<cr>")
    end,
    init = function()
        local isWin = vim.fn.has("win32")
        local isLinux = vim.fn.has("unix")

        if not (isWin or isLinux) then
            vim.api.nvim_err_writeln("Neither Windows nor Linux detected. Using undo defaults")

            return
        end

        local data_path = nil
        if isWin == 1 then
            data_path = os.getenv("USERPROFILE") .. "\\AppData\\Local\\nvim-data\\undodir"
        elseif isLinux == 1 then
            data_path = os.getenv("HOME") .. "/.vim/undodir"
        end

        vim.g.undotree_SetFocusWhenToggle = 1
        vim.g.undotree_WindowLayout = 3

        vim.opt.swapfile = false
        vim.opt.backup = false
        vim.opt.undofile = true
        vim.opt.undodir = data_path
    end,
}
