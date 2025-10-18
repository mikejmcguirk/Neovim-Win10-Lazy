require("mini.operators").setup({
    evaluate = {
        prefix = "g=",
        func = nil,
    },
    -- FUTURE: Unsure how to map something like this to ()
    exchange = {
        prefix = "",
        reindent_linewise = true,
    },
    multiply = {
        prefix = "gm",
    },
    replace = {
        prefix = "s",
        reindent_linewise = true,
    },
    sort = {
        prefix = "",
    },
})
