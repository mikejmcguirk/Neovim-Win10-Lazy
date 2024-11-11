return {
    {
        "windwp/nvim-autopairs",
        event = "InsertEnter",
        config = function()
            require("nvim-autopairs").setup({
                check_ts = true,
                map_bs = false, -- To keep my <backspace> mapping intact
            })
        end,
    },
}
