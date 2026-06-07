return {
    {
        callback_txt = "print('foo')",
        desc = "Some silly thing",
        desc_short = "wow",
        lhs = { "<leader>r" },
        modes = { "n" },
        opts = { noremap = true },
        plugs = { "some-plug-map" },
        rhs = "",
        tags_addtl = { "test-map" },
    },
    {
        callback_txt = "print('bar')",
        desc = "Another thing",
        desc_short = "woo",
        lhs = { "<leader>e" },
        modes = { "n", "x" },
        opts = { noremap = true },
        plugs = { "another-plug-map" },
        rhs = "",
        tags_addtl = { "testier-map" },
    },
}
