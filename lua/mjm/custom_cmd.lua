vim.api.nvim_create_user_command("We", "silent w | e", {}) -- Quick refresh if Treesitter bugs out

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
