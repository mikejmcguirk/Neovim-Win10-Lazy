-- FUTURE: This shouldn't open when you enter Lazy windows
return {
    "NvChad/nvim-colorizer.lua",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
        require("colorizer").setup({
            user_default_options = {
                names = false,
            },
        })
    end,
}
