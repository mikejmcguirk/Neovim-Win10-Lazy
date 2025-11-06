-- LOW: This activates in hover windows because their ft is markdown
return {
    "windwp/nvim-ts-autotag",
    ft = { "html", "markdown", "xml" },
    opts = { opts = { enable_close = true, enable_rename = true, enable_close_on_slash = false } },
}
