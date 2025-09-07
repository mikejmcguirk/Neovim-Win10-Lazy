---@type vim.lsp.Config
return {
    settings = {
        pylsp = {
            plugins = {
                pycodestyle = {
                    maxLineLength = 99,
                    ignore = {
                        "E201",
                        "E202",
                        "E203", -- Whitespace before ':' (Contradicts ruff formatter)
                        "E211",
                        "E225", -- Missing whitespace around operator
                        "E226", -- Missing whitespace around arithmetic operator
                        "E231", -- Missing whitespace after ,
                        "E261",
                        "E262",
                        "E265",
                        "E302",
                        "E303",
                        "E305",
                        "E501",
                        "E741", -- Ambiguous variable name
                        "W291", -- Trailing whitespace
                        "W292", -- No newline at end of file
                        "W293",
                        "W391",
                        "W503", -- Line break after binary operator
                    },
                },
            },
        },
    },
}
