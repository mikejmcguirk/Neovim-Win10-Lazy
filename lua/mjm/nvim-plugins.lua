local api = vim.api
local fn = vim.fn

-- MID: Need to run without bang because otherwise lazy doesn't allow the plugin file to source
api.nvim_cmd({ cmd = "packadd", args = { "nvim.undotree" } }, {})
vim.keymap.set("n", "<leader>u", function()
    local width = api.nvim_win_get_width(0) ---@type integer
    local partial_width = math.floor(width * 0.3) ---@type integer
    local capped_width = math.max(partial_width) ---@type integer
    local cmd = capped_width .. "vnew" ---@type string
    require("undotree").open({ command = cmd })
end)

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

    local create_temp_buf = require("nvim-tools.buf").create_temp_buf
    local temp_buf = create_temp_buf("wipe", true, "nofile", "", true)
    api.nvim_open_tabpage(temp_buf, true, { after = fn.tabpagenr("$") })
    require("difftool").open(bufnames[1], bufnames[2])
end)

-- MID: Can this be made to work with non-files? Would be useful to be able to diff temp buffers
