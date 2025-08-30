-- LOW: Create a cmd to rename the current buffer
-- LOW: Create a command to delete the current buffer and Git delist it

vim.api.nvim_create_user_command("We", "silent up | e", {}) -- Quick refresh if Treesitter bugs out

local function tab_kill()
    local confirm = vim.fn.confirm(
        "This will delete all buffers in the current tab. Unsaved changes will be lost. Proceed?",
        "&Yes\n&No",
        2
    )

    if confirm ~= 1 then
        return
    end

    local buffers = vim.fn.tabpagebuflist(vim.fn.tabpagenr())
    for _, buf in ipairs(buffers) do
        if vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_delete(buf, { force = true })
        end
    end
end

vim.api.nvim_create_user_command("TabKill", tab_kill, {})

local function close_floats()
    for _, win in pairs(vim.fn.getwininfo()) do
        local id = win.winid
        local config = vim.api.nvim_win_get_config(id)
        if config.relative and config.relative ~= "" then
            vim.api.nvim_win_close(id, false)
        end
    end
end

vim.api.nvim_create_user_command("CloseFloats", close_floats, {})
