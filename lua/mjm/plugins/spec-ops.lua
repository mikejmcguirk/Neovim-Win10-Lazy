local set = vim.keymap.set
-- https://github.com/mikejmcguirk/spec-ops

-- TODO: Interesting discussion about operator pending mode here
-- https://github.com/neovim/neovim/pull/36575

-- The plugin/ file automatically sets up lazy loading
-- vim.cmd.packadd({ vim.fn.escape("spec-ops", " "), bang = true, magic = { file = false } })

return {
    dir = "~/.local/share/nvim/site/pack/dev-plugins/opt/spec-ops/",
    init = function()
        ---@module "spec-ops"
        ---@type SpecOpsConfig
        local config = {
            global = {
                reg_handler = "target_only",
            },
            ops = {
                change = {
                    enabled = true,
                },
                delete = {
                    enabled = true,
                },
                paste = {
                    enabled = true,
                },
                substitute = {
                    enabled = true,
                },
                yank = {
                    enabled = true,
                },
            },
        }

        vim.g.spec_ops = config

        ------------
        -- Change --
        ------------

        set("o", "c", "<Plug>(SpecOpsChangeLineObject)")
        set("o", "w", "<Plug>(SpecOpsChangeWord)")
        set("o", "W", "<Plug>(SpecOpsChangeWORD)")

        set("n", "c", "<Plug>(SpecOpsChangeOperator)")
        set("n", "C", "<Plug>(SpecOpsChangeEol)")

        set("n", "<M-c>", '"_<Plug>(SpecOpsChangeOperator)')
        set("n", "<M-C>", '"_<Plug>(SpecOpsChangeEol)')

        set("x", "c", "<Plug>(SpecOpsChangeVisual)")
        set("x", "C", "<nop>")

        set("x", "<M-c>", '"_<Plug>(SpecOpsChangeVisual)')

        ------------
        -- Delete --
        ------------

        set("o", "d", "<Plug>(SpecOpsDeleteLineObject)")

        set("n", "d", "<Plug>(SpecOpsDeleteOperator)")
        set("n", "D", "<Plug>(SpecOpsDeleteEol)")

        set("n", "<M-d>", '"_<Plug>(SpecOpsDeleteOperator)')
        set("n", "<M-D>", '"_<Plug>(SpecOpsDeleteEol)')

        set("x", "d", "<Plug>(SpecOpsDeleteVisual)")
        set("x", "D", "<nop>")

        set("x", "<M-d>", '"_<Plug>(SpecOpsDeleteVisual)')

        ----------------
        -- Substitute --
        ----------------

        -- set("o", "s", "<Plug>(SpecOpsSubstituteLineObject)")
        --
        -- set("n", "s", "<Plug>(SpecOpsSubstituteOperator)")
        -- set("n", "S", "<Plug>(SpecOpsSubstituteEol)")
        --
        -- set("n", "<M-s>", '"+<Plug>(SpecOpsSubstituteOperator)')
        -- set("n", "<M-S>", '"+<Plug>(SpecOpsSubstituteEol)')
        --
        -- set("x", "s", "<Plug>(SpecOpsSubstituteVisual)")
        -- set("x", "<M-s>", '"+<Plug>(SpecOpsSubstituteVisual)')

        -----------
        -- Paste --
        -----------

        -- set("n", "p", "<Plug>(SpecOpsPasteNormalAfterCursor)")
        -- set("n", "P", "<Plug>(SpecOpsPasteNormalBeforeCursor)")
        --
        -- set("n", "<M-p>", '"+<Plug>(SpecOpsPasteNormalAfterCursor)')
        -- set("n", "<M-P>", '"+<Plug>(SpecOpsPasteNormalBeforeCursor)')
        --
        -- set("n", "[p", "<Plug>(SpecOpsPasteLinewiseBefore)")
        -- set("n", "]p", "<Plug>(SpecOpsPasteLinewiseAfter)")
        --
        -- set("n", "<M-[>p", '"+<Plug>(SpecOpsPasteLinewiseBefore)')
        -- set("n", "<M-]>p", '"+<Plug>(SpecOpsPasteLinewiseAfter)')
        -- set("n", "<M-[><M-p>", '"+<Plug>(SpecOpsPasteLinewiseBefore)')
        -- set("n", "<M-]><M-p>", '"+<Plug>(SpecOpsPasteLinewiseAfter)')
        --
        -- set("x", "p", "<Plug>(SpecOpsPasteVisual)")
        -- set("x", "P", "<Plug>(SpecOpsPasteVisualAndYank)")
        --
        -- set("x", "<M-p>", '"+<Plug>(SpecOpsPasteVisual)')
        -- set("x", "<M-P>", '"+<Plug>(SpecOpsPasteVisualAndYank)')

        set("n", "[p", '<Cmd>exe "put! " . v:register<CR>')
        set("n", "]p", '<Cmd>exe "put "  . v:register<CR>')

        ----------
        -- Yank --
        ----------

        set("o", "y", "<Plug>(SpecOpsYankLineObject)")

        set("n", "y", "<Plug>(SpecOpsYankOperator)")
        set("n", "Y", "<Plug>(SpecOpsYankEol)")

        set("n", "<M-y>", '"+<Plug>(SpecOpsYankOperator)')
        set("n", "<M-Y>", '"+<Plug>(SpecOpsYankEol)')

        set("x", "y", "<Plug>(SpecOpsYankVisual)")
        set("x", "Y", "<nop>")

        set("x", "<M-y>", '"+<Plug>(SpecOpsYankVisual)')
    end,
}
