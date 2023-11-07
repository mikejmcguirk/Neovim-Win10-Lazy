vim.keymap.set("n", "ZZ", "<Nop>", Opts)
vim.keymap.set("n", "ZQ", "<Nop>", Opts)

vim.keymap.set({ "n", "i", "v" }, "<up>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v" }, "<down>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v" }, "<left>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v" }, "<right>", "<Nop>", Opts)

vim.keymap.set({ "n", "i", "v", "c" }, "<PageUp>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<PageDown>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<Home>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<End>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<Insert>", "<Nop>", Opts)

vim.keymap.set("n", "gh", "<nop>", Opts)
vim.keymap.set("n", "gH", "<nop>", Opts)

vim.keymap.set({ "n", "v" }, "s", "<Nop>", Opts)
vim.keymap.set("n", "S", "<Nop>", Opts) -- Used in visual mode by vim-surround

vim.keymap.set("n", "Q", "<nop>", Opts)

-- vim.keymap.set("n", "H", "<Nop>", Opts) -- Used for a custom mapping
vim.keymap.set({ "n", "v" }, "M", "<Nop>", Opts)
vim.keymap.set({ "n", "v" }, "L", "<Nop>", Opts)

vim.keymap.set("n", "{", "<Nop>", Opts)
vim.keymap.set("n", "}", "<Nop>", Opts)
vim.keymap.set("n", "[m", "<Nop>", Opts)
vim.keymap.set("n", "]m", "<Nop>", Opts)
vim.keymap.set("n", "[M", "<Nop>", Opts)
vim.keymap.set("n", "]M", "<Nop>", Opts)

vim.opt.mouse = "a" -- Otherwise, the terminal handles mouse functionality
vim.opt.mousemodel = "extend" -- Disables terminal right-click paste

local mouse_maps = {
    "LeftMouse",
    "2-LeftMouse",
    "3-LeftMouse",
    "4-LeftMouse",
    "C-LeftMouse",
    "C-2-LeftMouse",
    "C-3-LeftMouse",
    "C-4-LeftMouse",
    "M-LeftMouse",
    "M-2-LeftMouse",
    "M-3-LeftMouse",
    "M-4-LeftMouse",
    "C-M-LeftMouse",
    "C-M-2-LeftMouse",
    "C-M-3-LeftMouse",
    "C-M-4-LeftMouse",
    "RightMouse",
    "2-RightMouse",
    "3-RightMouse",
    "4-RightMouse",
    "A-RightMouse",
    "S-RightMouse",
    "C-RightMouse",
    "C-2-RightMouse",
    "C-3-RightMouse",
    "C-4-RightMouse",
    "C-A-RightMouse",
    "C-S-RightMouse",
    "M-RightMouse",
    "M-2-RightMouse",
    "M-3-RightMouse",
    "M-4-RightMouse",
    "M-A-RightMouse",
    "M-S-RightMouse",
    "M-C-RightMouse",
    "C-M-RightMouse",
    "C-M-2-RightMouse",
    "C-M-3-RightMouse",
    "C-M-4-RightMouse",
    "C-M-A-RightMouse",
    "C-M-S-RightMouse",
    "C-M-C-RightMouse",
    "LeftDrag",
    "RightDrag",
    "LeftRelease",
    "RightRelease",
    "C-LeftDrag",
    "C-RightDrag",
    "C-LeftRelease",
    "C-RightRelease",
    "M-LeftDrag",
    "M-RightDrag",
    "M-LeftRelease",
    "M-RightRelease",
    "C-M-LeftDrag",
    "C-M-RightDrag",
    "C-M-LeftRelease",
    "C-M-RightRelease",
    "MiddleMouse",
    "2-MiddleMouse",
    "3-MiddleMouse",
    "4-MiddleMouse",
    "C-MiddleMouse",
    "C-2-MiddleMouse",
    "C-3-MiddleMouse",
    "C-4-MiddleMouse",
    "M-MiddleMouse",
    "M-2-MiddleMouse",
    "M-3-MiddleMouse",
    "M-4-MiddleMouse",
    "C-M-MiddleMouse",
    "C-M-2-MiddleMouse",
    "C-M-3-MiddleMouse",
    "C-M-4-MiddleMouse",
    "ScrollWheelUp",
    "S-ScrollWheelUp",
    "ScrollWheelDown",
    "S-ScrollWheelDown",
    "C-ScrollWheelUp",
    "C-S-ScrollWheelUp",
    "C-ScrollWheelDown",
    "C-S-ScrollWheelDown",
    "M-ScrollWheelUp",
    "M-S-ScrollWheelUp",
    "M-ScrollWheelDown",
    "M-S-ScrollWheelDown",
    "C-M-ScrollWheelUp",
    "C-M-S-ScrollWheelUp",
    "C-M-ScrollWheelDown",
    "C-M-S-ScrollWheelDown",
}

for _, map in pairs(mouse_maps) do
    vim.keymap.set({ "n", "i", "v", "c" }, "<" .. map .. ">", "<Nop>", Opts)
end
