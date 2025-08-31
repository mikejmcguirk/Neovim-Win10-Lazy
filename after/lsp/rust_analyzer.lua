-- FUTURE: Figure out why code lens isn't working
return {
    settings = {
        ["rust-analyzer"] = {
            checkOnSave = true,
            check = {
                command = "clippy",
            },
            -- lens = {
            --     enable = true,
            --     run = { enable = true },
            --     debug = { enable = true },
            --     implementations = { enable = true },
            --     references = { enable = true },
            -- },
        },
    },
}
