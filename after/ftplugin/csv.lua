vim.keymap.set("n", "<localleader>s", function()
    local year = os.date("%Y")
    local month = os.date("%m")
    local day = os.date("%d")
    local date = year .. "-" .. month .. "-" .. day

    return "Go" .. date .. ",,<left><space>"
end, { buffer = 0, expr = true })
