vim.keymap.set("n", "ZZ", "<Nop>")
vim.keymap.set("n", "ZQ", "<Nop>")

vim.keymap.set("x", "u", "<Nop>")
vim.keymap.set("x", "q", "<Nop>")
vim.keymap.set("n", "Q", "<nop>")
vim.keymap.set("n", "gQ", "<nop>")
vim.keymap.set("n", "gh", "<nop>")
vim.keymap.set("n", "gH", "<nop>")
vim.keymap.set("n", "gs", "<nop>")

vim.keymap.set("n", "<C-z>", "<nop>")

vim.keymap.set("x", "<C-w>", "<nop>")

-- Even mapping <C-c> in operator pending mode does not fix these
local bad_wincmds = { "c", "f", "w", "i", "+", "-" }
for _, key in pairs(bad_wincmds) do
    vim.keymap.set("n", "<C-w>" .. key, "<nop>")
    vim.keymap.set("n", "<C-w><C-" .. key .. ">", "<nop>")
end

vim.keymap.set({ "n", "x" }, "[[", "<Nop>")
vim.keymap.set({ "n", "x" }, "]]", "<Nop>")
vim.keymap.set({ "n", "x" }, "[]", "<Nop>")
vim.keymap.set({ "n", "x" }, "][", "<Nop>")
vim.keymap.set({ "n", "x" }, "[/", "<Nop>")
vim.keymap.set({ "n", "x" }, "]/", "<Nop>")

-- Purposefully left alone in cmd mode
vim.keymap.set({ "n", "i", "x" }, "<left>", "<Nop>")
vim.keymap.set({ "n", "i", "x" }, "<right>", "<Nop>")
vim.keymap.set({ "n", "i", "x" }, "<up>", "<Nop>")
vim.keymap.set({ "n", "i", "x" }, "<down>", "<Nop>")

vim.keymap.set({ "n", "i", "x" }, "<pageup>", "<Nop>")
vim.keymap.set({ "n", "i", "x" }, "<pagedown>", "<Nop>")
vim.keymap.set({ "n", "i", "x" }, "<home>", "<Nop>")
vim.keymap.set({ "n", "i", "x" }, "<end>", "<Nop>")
vim.keymap.set({ "n", "i", "x" }, "<insert>", "<Nop>")
vim.keymap.set({ "n", "x" }, "<del>", "<Nop>")

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
    vim.keymap.set({ "n", "i", "x", "c" }, "<" .. map .. ">", "<Nop>")
end
