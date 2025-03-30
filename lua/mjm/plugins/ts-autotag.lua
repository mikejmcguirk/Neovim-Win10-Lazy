return {
    "windwp/nvim-ts-autotag",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
        require("nvim-ts-autotag").setup({
            opts = {
                enable_close = true,
                enable_rename = true,
                enable_close_on_slash = false,
            },
            per_filetype = {
                -- Disable because it contradicts my Rust ftplugin pair code
                ["rust"] = {
                    enable_close = false,
                    enable_rename = false,
                    enable_close_on_slash = false,
                },
            },
        })
    end,
}
