local api = vim.api

api.nvim_cmd({ cmd = "packadd", args = { "nvim.difftool" }, bang = true }, {})

vim.keymap.set("n", "<leader>d", function()
    local bufnames = {} ---@type string[]
    for i = 1, vim.fn.winnr("$") do
        if #bufnames >= 2 then
            break
        end
        local buf = api.nvim_win_get_buf(vim.fn.win_getid(i)) ---@type integer
        local bufname = api.nvim_buf_get_name(buf) ---@type string
        if #bufname > 0 then
            bufnames[#bufnames + 1] = bufname
        end
    end

    if #bufnames < 2 then
        api.nvim_echo({ { "Not enough valid buffers to diff" } }, false, {})
        return
    end

    api.nvim_cmd({ cmd = "tabnew" }, {})
    api.nvim_set_option_value("bufhidden", "wipe", { buf = 0 })
    require("difftool").open(bufnames[1], bufnames[2])
end)
