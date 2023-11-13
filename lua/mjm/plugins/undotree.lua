return {
    "mbbill/undotree",
    lazy = false,
    event = { "BufReadPre", "BufNewFile" },
    config = function()
        vim.keymap.set("n", "<leader>ut", "<cmd>UndotreeToggle<cr>")
    end,
    init = function()
        local winHome = os.getenv("USERPROFILE")
        local winNvimDataPath = "\\AppData\\Local\\nvim-data\\undodir"
        local isWin = vim.fn.has("win32")

        local linuxHome = os.getenv("HOME")
        local linuxNvimDataPath = "/.vim/undodir"
        local isLinux = vim.fn.has("unix")

        vim.g.undotree_SetFocusWhenToggle = 1
        vim.g.undotree_WindowLayout = 3

        if winHome and winNvimDataPath and isWin == 1 then
            vim.opt.swapfile = false
            vim.opt.backup = false
            vim.opt.undofile = true
            vim.opt.undodir = winHome .. winNvimDataPath
        elseif linuxHome and linuxNvimDataPath and isLinux == 1 then
            vim.opt.swapfile = false
            vim.opt.backup = false
            vim.opt.undofile = true
            vim.opt.undodir = linuxHome .. linuxNvimDataPath
        else
            print("Could not set undodir for undotree. Using Nvim defaults.")
            print("Debug Information:")

            if isWin then
                print("USERPROFILE env variable: " .. (winHome or "Not set"))
                print("Nvim Data Path: " .. (winNvimDataPath or "Not set"))
                print("Is Windows: " .. (isWin == 1 and "True" or "False"))
            elseif isLinux then
                print("HOME env variable: " .. (linuxHome or "Not set"))
                print("Nvim Data Path: " .. (linuxNvimDataPath or "Not set"))
                print("Is Linux: " .. (isLinux == 1 and "True" or "False"))
            else
                print("Is Windows: " .. (isWin == 1 and "True" or "False"))
                print("Is Linux: " .. (isLinux == 1 and "True" or "False"))
            end
        end
    end,
}
