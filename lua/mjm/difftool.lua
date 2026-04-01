local api = vim.api
local fn = vim.fn

api.nvim_cmd({ cmd = "packadd", args = { "nvim.difftool" }, bang = true }, {})

vim.keymap.set("n", "<leader>d", function()
    local bufnames = {} ---@type string[]
    local max_winnr = fn.winnr("$")
    for i = 1, max_winnr do
        if #bufnames >= 2 then
            break
        end

        local buf = api.nvim_win_get_buf(fn.win_getid(i))
        local bufname = api.nvim_buf_get_name(buf)
        if #bufname > 0 then
            bufnames[#bufnames + 1] = bufname
        end
    end

    if #bufnames < 2 then
        api.nvim_echo({ { "Not enough valid buffers to diff" } }, false, {})
        return
    end

    local temp_buf = require("nvim-tools.buf").create_temp_buf()
    api.nvim_open_tabpage(temp_buf, true, { after = fn.tabpagenr("$") })
    require("difftool").open(bufnames[1], bufnames[2])
end)

-- MID: Can this be made to work with non-files? Would be useful to be able to diff temp buffers
