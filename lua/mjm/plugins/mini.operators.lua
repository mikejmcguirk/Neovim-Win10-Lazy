return {
    "nvim-mini/mini.operators",
    version = "*",
    opts = {
        evaluate = { prefix = "g=", func = nil },
        -- MAYBE: Unsure how to map something like this to ()
        exchange = { prefix = "", reindent_linewise = true },
        multiply = { prefix = "gm" },
        replace = { prefix = "s", reindent_linewise = true },
        sort = { prefix = "" },
    },
}
