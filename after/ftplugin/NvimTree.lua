vim.opt_local.colorcolumn = ""

local function nvim_tree_open_oil()
    local oil = require("oil")
    local tree = require("nvim-tree.lib")

    local node = tree.get_node_at_cursor()
    local path, is_dir

    if node and node.fs_stat then
        is_dir = node.fs_stat.type == "directory"
        path = is_dir and node.absolute_path or node.parent.absolute_path
    else
        local base = tree.get_nodes().absolute_path
        is_dir = node.name == ".." or node.name == "."
        path = base
    end

    if is_dir then
        oil.toggle_float(path)

        return
    end

    local function bufenter_cb(e, tries)
        if not oil.get_entry_on_line(e.buf, 1) then
            tries = tries or 0

            if tries <= 8 then
                vim.defer_fn(function()
                    bufenter_cb(e, tries + 1)
                end, tries * tries)
            end

            return
        end

        for i = 1, vim.api.nvim_buf_line_count(e.buf) do
            local entry = oil.get_entry_on_line(e.buf, i)

            if entry and entry.name == node.name then
                vim.api.nvim_win_set_cursor(0, { i, 0 })

                break
            end
        end
    end

    vim.api.nvim_create_autocmd("BufEnter", {
        once = true,
        pattern = "oil://*",
        callback = bufenter_cb,
    })

    oil.toggle_float(path)
end

vim.keymap.set("n", "i", nvim_tree_open_oil, { buffer = 0 })
