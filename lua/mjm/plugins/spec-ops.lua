-- https://github.com/mikejmcguirk/spec-ops

-- The plugin/ file automatically sets up lazy loading
vim.cmd.packadd({ vim.fn.escape("spec-ops", " "), bang = true, magic = { file = false } })

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

vim.keymap.set("o", "c", "<Plug>(SpecOpsChangeLineObject)")
vim.keymap.set("o", "w", "<Plug>(SpecOpsChangeWord)")
vim.keymap.set("o", "W", "<Plug>(SpecOpsChangeWORD)")

vim.keymap.set("n", "c", "<Plug>(SpecOpsChangeOperator)")
vim.keymap.set("n", "C", "<Plug>(SpecOpsChangeEol)")

vim.keymap.set("n", "<M-c>", '"_<Plug>(SpecOpsChangeOperator)')
vim.keymap.set("n", "<M-C>", '"_<Plug>(SpecOpsChangeEol)')

vim.keymap.set("x", "c", "<Plug>(SpecOpsChangeVisual)")
vim.keymap.set("x", "C", "<nop>")

vim.keymap.set("x", "<M-c>", '"_<Plug>(SpecOpsChangeVisual)')

------------
-- Delete --
------------

vim.keymap.set("o", "d", "<Plug>(SpecOpsDeleteLineObject)")

vim.keymap.set("n", "d", "<Plug>(SpecOpsDeleteOperator)")
vim.keymap.set("n", "D", "<Plug>(SpecOpsDeleteEol)")

vim.keymap.set("n", "<M-d>", '"_<Plug>(SpecOpsDeleteOperator)')
vim.keymap.set("n", "<M-D>", '"_<Plug>(SpecOpsDeleteEol)')

vim.keymap.set("x", "d", "<Plug>(SpecOpsDeleteVisual)")
vim.keymap.set("x", "D", "<nop>")

vim.keymap.set("x", "<M-d>", '"_<Plug>(SpecOpsDeleteVisual)')

----------------
-- Substitute --
----------------

-- vim.keymap.set("o", "s", "<Plug>(SpecOpsSubstituteLineObject)")
--
-- vim.keymap.set("n", "s", "<Plug>(SpecOpsSubstituteOperator)")
-- vim.keymap.set("n", "S", "<Plug>(SpecOpsSubstituteEol)")
--
-- vim.keymap.set("n", "<M-s>", '"+<Plug>(SpecOpsSubstituteOperator)')
-- vim.keymap.set("n", "<M-S>", '"+<Plug>(SpecOpsSubstituteEol)')
--
-- vim.keymap.set("x", "s", "<Plug>(SpecOpsSubstituteVisual)")
-- vim.keymap.set("x", "<M-s>", '"+<Plug>(SpecOpsSubstituteVisual)')

-----------
-- Paste --
-----------

-- vim.keymap.set("n", "p", "<Plug>(SpecOpsPasteNormalAfterCursor)")
-- vim.keymap.set("n", "P", "<Plug>(SpecOpsPasteNormalBeforeCursor)")
--
-- vim.keymap.set("n", "<M-p>", '"+<Plug>(SpecOpsPasteNormalAfterCursor)')
-- vim.keymap.set("n", "<M-P>", '"+<Plug>(SpecOpsPasteNormalBeforeCursor)')
--
-- vim.keymap.set("n", "[p", "<Plug>(SpecOpsPasteLinewiseBefore)")
-- vim.keymap.set("n", "]p", "<Plug>(SpecOpsPasteLinewiseAfter)")
--
-- vim.keymap.set("n", "<M-[>p", '"+<Plug>(SpecOpsPasteLinewiseBefore)')
-- vim.keymap.set("n", "<M-]>p", '"+<Plug>(SpecOpsPasteLinewiseAfter)')
-- vim.keymap.set("n", "<M-[><M-p>", '"+<Plug>(SpecOpsPasteLinewiseBefore)')
-- vim.keymap.set("n", "<M-]><M-p>", '"+<Plug>(SpecOpsPasteLinewiseAfter)')
--
-- vim.keymap.set("x", "p", "<Plug>(SpecOpsPasteVisual)")
-- vim.keymap.set("x", "P", "<Plug>(SpecOpsPasteVisualAndYank)")
--
-- vim.keymap.set("x", "<M-p>", '"+<Plug>(SpecOpsPasteVisual)')
-- vim.keymap.set("x", "<M-P>", '"+<Plug>(SpecOpsPasteVisualAndYank)')

----------
-- Yank --
----------

vim.keymap.set("o", "y", "<Plug>(SpecOpsYankLineObject)")

vim.keymap.set("n", "y", "<Plug>(SpecOpsYankOperator)")
vim.keymap.set("n", "Y", "<Plug>(SpecOpsYankEol)")

vim.keymap.set("n", "<M-y>", '"+<Plug>(SpecOpsYankOperator)')
vim.keymap.set("n", "<M-Y>", '"+<Plug>(SpecOpsYankEol)')

vim.keymap.set("x", "y", "<Plug>(SpecOpsYankVisual)")
vim.keymap.set("x", "Y", "<nop>")

vim.keymap.set("x", "<M-y>", '"+<Plug>(SpecOpsYankVisual)')
