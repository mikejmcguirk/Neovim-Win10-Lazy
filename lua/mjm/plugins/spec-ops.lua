-- https://github.com/mikejmcguirk/spec-ops

-- The plugin/ file automatically sets up lazy loading
vim.cmd.packadd({ vim.fn.escape("spec-ops", " "), bang = true, magic = { file = false } })

--- @module "spec-ops"
--- @type SpecOpsConfig
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

Map("o", "c", "<Plug>(SpecOpsChangeLineObject)")
Map("o", "w", "<Plug>(SpecOpsChangeWord)")
Map("o", "W", "<Plug>(SpecOpsChangeWORD)")

Map("n", "c", "<Plug>(SpecOpsChangeOperator)")
Map("n", "C", "<Plug>(SpecOpsChangeEol)")

Map("n", "<M-c>", '"_<Plug>(SpecOpsChangeOperator)')
Map("n", "<M-C>", '"_<Plug>(SpecOpsChangeEol)')

Map("x", "c", "<Plug>(SpecOpsChangeVisual)")
Map("x", "C", "<nop>")

Map("x", "<M-c>", '"_<Plug>(SpecOpsChangeVisual)')

------------
-- Delete --
------------

Map("o", "d", "<Plug>(SpecOpsDeleteLineObject)")

Map("n", "d", "<Plug>(SpecOpsDeleteOperator)")
Map("n", "D", "<Plug>(SpecOpsDeleteEol)")

Map("n", "<M-d>", '"_<Plug>(SpecOpsDeleteOperator)')
Map("n", "<M-D>", '"_<Plug>(SpecOpsDeleteEol)')

Map("x", "d", "<Plug>(SpecOpsDeleteVisual)")
Map("x", "D", "<nop>")

Map("x", "<M-d>", '"_<Plug>(SpecOpsDeleteVisual)')

----------------
-- Substitute --
----------------

-- Map("o", "s", "<Plug>(SpecOpsSubstituteLineObject)")
--
-- Map("n", "s", "<Plug>(SpecOpsSubstituteOperator)")
-- Map("n", "S", "<Plug>(SpecOpsSubstituteEol)")
--
-- Map("n", "<M-s>", '"+<Plug>(SpecOpsSubstituteOperator)')
-- Map("n", "<M-S>", '"+<Plug>(SpecOpsSubstituteEol)')
--
-- Map("x", "s", "<Plug>(SpecOpsSubstituteVisual)")
-- Map("x", "<M-s>", '"+<Plug>(SpecOpsSubstituteVisual)')

-----------
-- Paste --
-----------

-- Map("n", "p", "<Plug>(SpecOpsPasteNormalAfterCursor)")
-- Map("n", "P", "<Plug>(SpecOpsPasteNormalBeforeCursor)")
--
-- Map("n", "<M-p>", '"+<Plug>(SpecOpsPasteNormalAfterCursor)')
-- Map("n", "<M-P>", '"+<Plug>(SpecOpsPasteNormalBeforeCursor)')
--
-- Map("n", "[p", "<Plug>(SpecOpsPasteLinewiseBefore)")
-- Map("n", "]p", "<Plug>(SpecOpsPasteLinewiseAfter)")
--
-- Map("n", "<M-[>p", '"+<Plug>(SpecOpsPasteLinewiseBefore)')
-- Map("n", "<M-]>p", '"+<Plug>(SpecOpsPasteLinewiseAfter)')
-- Map("n", "<M-[><M-p>", '"+<Plug>(SpecOpsPasteLinewiseBefore)')
-- Map("n", "<M-]><M-p>", '"+<Plug>(SpecOpsPasteLinewiseAfter)')
--
-- Map("x", "p", "<Plug>(SpecOpsPasteVisual)")
-- Map("x", "P", "<Plug>(SpecOpsPasteVisualAndYank)")
--
-- Map("x", "<M-p>", '"+<Plug>(SpecOpsPasteVisual)')
-- Map("x", "<M-P>", '"+<Plug>(SpecOpsPasteVisualAndYank)')

----------
-- Yank --
----------

Map("o", "y", "<Plug>(SpecOpsYankLineObject)")

Map("n", "y", "<Plug>(SpecOpsYankOperator)")
Map("n", "Y", "<Plug>(SpecOpsYankEol)")

Map("n", "<M-y>", '"+<Plug>(SpecOpsYankOperator)')
Map("n", "<M-Y>", '"+<Plug>(SpecOpsYankEol)')

Map("x", "y", "<Plug>(SpecOpsYankVisual)")
Map("x", "Y", "<nop>")

Map("x", "<M-y>", '"+<Plug>(SpecOpsYankVisual)')
