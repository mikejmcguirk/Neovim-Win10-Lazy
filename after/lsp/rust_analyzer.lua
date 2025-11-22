-- https://github.com/neovim/neovim/discussions/34353#discussioncomment-13596488
-- Used the VSCode Rust-Analyzer extension to get info
-- https://github.com/rust-lang/rust-analyzer/tree/5b852da4c3852d030ebca67746980bc0288a85ec/editors/code
-- https://github.com/rust-lang/rust-analyzer/blob/5b852da4c3852d030ebca67746980bc0288a85ec/editors/code/src/client.ts#L307-L329

---@type vim.lsp.Config
return {
    settings = {
        ["rust-analyzer"] = {
            checkOnSave = true,
            check = { command = "clippy", extraArgs = { "--no-deps" } },
            lens = {
                debug = { enable = true },
                enable = true,
                implementations = { enable = true },
                references = {
                    adt = { enable = true },
                    enumVariant = { enable = true },
                    method = { enable = true },
                    trait = { enable = true },
                },
                run = { enable = true },
                updateTest = { enable = true },
            },
            procMacro = { enable = true },
        },
    },
}
