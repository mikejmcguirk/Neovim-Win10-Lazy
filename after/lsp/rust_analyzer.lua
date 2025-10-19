-- https://github.com/neovim/neovim/discussions/34353#discussioncomment-13596488
-- Used the VSCode Rust-Analyzer extension to get info
-- https://github.com/rust-lang/rust-analyzer/tree/5b852da4c3852d030ebca67746980bc0288a85ec/editors/code
-- https://github.com/rust-lang/rust-analyzer/blob/5b852da4c3852d030ebca67746980bc0288a85ec/editors/code/src/client.ts#L307-L329

-- vim.lsp.commands["rust-analyzer.runSingle"] = function(command)
--     local r = command.arguments[1]
--     local cmd = { "cargo", unpack(r.args.cargoArgs) }
--     if r.args.executableArgs and #r.args.executableArgs > 0 then
--         vim.list_extend(cmd, { "--", unpack(r.args.executableArgs) })
--     end
--
--     local proc = vim.system(cmd, { cwd = r.args.cwd }):wait()
--
--     if proc.code == 0 then
--         vim.notify(proc.stdout, vim.log.levels.INFO)
--     else
--         vim.notify(proc.stderr, vim.log.levels.ERROR)
--     end
-- end

---@type vim.lsp.Config
return {
    capabilities = {
        experimental = {
            commands = {
                commands = {
                    "rust-analyzer.showReferences",
                    -- "rust-analyzer.runSingle",
                    -- "rust-analyzer.debugSingle",
                },
            },
        },
    },
    settings = {
        ["rust-analyzer"] = {
            checkOnSave = true,
            check = {
                command = "clippy",
            },
            lens = {
                enable = true,
                run = { enable = true },
                implementations = { enable = true },
                references = {
                    adt = { enable = true },
                    method = { enable = true },
                    trait = { enable = true },
                    enumVariant = { enable = true },
                },
            },
        },
    },
}

-- LOW: Curious how to make the run commands work. Also feels like it could just be a vim.system
-- thing
