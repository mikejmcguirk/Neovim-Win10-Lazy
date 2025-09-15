-- TODO: The hotkeys here need to line up with the filter functions and the get functions
-- TODO: Do I resize on sort?

local M = {}

vim.keymap.set("n", "<leader>qo", "<nop>")

---------------------
--- Wrapper Funcs ---
---------------------

function M.qf_sort_wrapper(sort_func)
    local list_size = vim.fn.getqflist({ size = true }).size --- @type integer
    if (not list_size) or list_size == 0 then
        vim.api.nvim_echo({ { "No list entries", "" } }, false, {})
        return
    end

    if list_size == 1 then return end

    local list_nr = (function()
        if vim.v.count > 0 then
            return math.min(vim.v.count, vim.fn.getqflist({ nr = "$" }).nr)
        else
            return vim.fn.getqflist({ nr = 0 }).nr
        end
    end)() --- @type integer

    local qf_win = (function()
        for _, win in pairs(vim.api.nvim_tabpage_list_wins(0)) do
            if vim.fn.win_gettype(win) == "quickfix" then return win end
        end

        return nil
    end)() --- @type integer

    local view = qf_win and vim.api.nvim_win_call(qf_win, vim.fn.winsaveview) or nil

    local list = vim.fn.getqflist({ nr = list_nr, items = true }) --- @type table
    table.sort(list.items, sort_func)
    vim.fn.setqflist({}, "r", { nr = list_nr, items = list.items })

    if qf_win and view then
        view.topline = math.max(view.topline, 0)
        vim.api.nvim_win_call(qf_win, function() vim.fn.winrestview(view) end)
    end
end

function M.ll_sort_wrapper(sort_func)
    local cur_win = vim.api.nvim_get_current_win()

    local list_size = vim.fn.getloclist(cur_win, { size = true }).size --- @type integer
    if (not list_size) or list_size == 0 then
        vim.api.nvim_echo({ { "No list entries", "" } }, false, {})
        return
    end

    if list_size == 1 then return end

    local list_nr = (function()
        if vim.v.count > 0 then
            return math.min(vim.v.count, vim.fn.getloclist(cur_win, { nr = "$" }).nr)
        else
            return vim.fn.getloclist(cur_win, { nr = 0 }).nr
        end
    end)() --- @type integer

    local loclist_win = (function()
        for _, win in pairs(vim.api.nvim_tabpage_list_wins(0)) do
            if vim.fn.win_gettype(win) == "loclist" then return win end
        end

        return nil
    end)() --- @type integer

    local view = loclist_win and vim.api.nvim_win_call(loclist_win, vim.fn.winsaveview) or nil

    local list = vim.fn.getloclist(cur_win, { nr = list_nr, items = true }) --- @type table
    table.sort(list.items, sort_func)
    vim.fn.setloclist(cur_win, {}, "r", { nr = list_nr, items = list.items })

    if loclist_win and view then
        view.topline = math.max(view.topline, 0)
        vim.api.nvim_win_call(loclist_win, function() vim.fn.winrestview(view) end)
    end
end

-------------------
--- Basic Sorts ---
-------------------

-- TODO: Do I underline the sort wrappers? Not sure if I want to make guarantees about these
-- TODO: probably outline the line number checks, since you can just return false

function M.sort_fname_asc(a, b)
    if (not a) or not b then return false end

    if a.bufnr and b.bufnr then
        local fname_a = vim.fn.bufname(a.bufnr)
        local fname_b = vim.fn.bufname(b.bufnr)

        if (fname_a and fname_b) and fname_a ~= fname_b then return fname_a < fname_b end
    end

    if (a.lnum and b.lnum) and a.lnum ~= b.lnum then return a.lnum < b.lnum end
    if (a.col and b.col) and a.col ~= b.col then return a.col < b.col end
    if (a.end_lnum and b.end_lnum) and a.end_lnum ~= b.end_lnum then
        return a.end_lnum < b.end_lnum
    end
    if (a.end_col and b.end_col) and a.end_col ~= b.end_col then return a.end_col < b.end_col end

    return false
end

function M.sort_fname_desc(a, b)
    if (not a) or not b then return false end

    if a.bufnr and b.bufnr then
        local fname_a = vim.fn.bufname(a.bufnr)
        local fname_b = vim.fn.bufname(b.bufnr)

        if (fname_a and fname_b) and fname_a ~= fname_b then return fname_a < fname_b end
    end

    if (a.lnum and b.lnum) and a.lnum ~= b.lnum then return a.lnum > b.lnum end
    if (a.col and b.col) and a.col ~= b.col then return a.col > b.col end
    if (a.end_lnum and b.end_lnum) and a.end_lnum ~= b.end_lnum then
        return a.end_lnum > b.end_lnum
    end
    if (a.end_col and b.end_col) and a.end_col ~= b.end_col then return a.end_col > b.end_col end

    return false
end

vim.keymap.set("n", "<leader>qof", function() M.qf_sort_wrapper(M.sort_fname_asc) end)
vim.keymap.set("n", "<leader>qoF", function() M.qf_sort_wrapper(M.sort_fname_desc) end)
vim.keymap.set("n", "<leader>lof", function() M.ll_sort_wrapper(M.sort_fname_asc) end)
vim.keymap.set("n", "<leader>loF", function() M.ll_sort_wrapper(M.sort_fname_desc) end)

function M.sort_type_asc(a, b)
    if (not a) or not b then return false end

    if (a.type and b.type) and a.type ~= b.type then return a.type < b.type end

    if a.bufnr and b.bufnr then
        local fname_a = vim.fn.bufname(a.bufnr)
        local fname_b = vim.fn.bufname(b.bufnr)

        if (fname_a and fname_b) and fname_a ~= fname_b then return fname_a < fname_b end
    end

    if (a.lnum and b.lnum) and a.lnum ~= b.lnum then return a.lnum < b.lnum end
    if (a.col and b.col) and a.col ~= b.col then return a.col < b.col end
    if (a.end_lnum and b.end_lnum) and a.end_lnum ~= b.end_lnum then
        return a.end_lnum < b.end_lnum
    end
    if (a.end_col and b.end_col) and a.end_col ~= b.end_col then return a.end_col < b.end_col end

    return false
end

function M.sort_type_desc(a, b)
    if (not a) or not b then return false end

    if (a.type and b.type) and a.type ~= b.type then return a.type > b.type end

    if a.bufnr and b.bufnr then
        local fname_a = vim.fn.bufname(a.bufnr)
        local fname_b = vim.fn.bufname(b.bufnr)

        if (fname_a and fname_b) and fname_a ~= fname_b then return fname_a > fname_b end
    end

    if (a.lnum and b.lnum) and a.lnum ~= b.lnum then return a.lnum > b.lnum end
    if (a.col and b.col) and a.col ~= b.col then return a.col > b.col end
    if (a.end_lnum and b.end_lnum) and a.end_lnum ~= b.end_lnum then
        return a.end_lnum > b.end_lnum
    end
    if (a.end_col and b.end_col) and a.end_col ~= b.end_col then return a.end_col > b.end_col end

    return false
end

vim.keymap.set("n", "<leader>qot", function() M.qf_sort_wrapper(M.sort_type_asc) end)
vim.keymap.set("n", "<leader>qoT", function() M.qf_sort_wrapper(M.sort_type_desc) end)
vim.keymap.set("n", "<leader>lot", function() M.ll_sort_wrapper(M.sort_type_asc) end)
vim.keymap.set("n", "<leader>loT", function() M.ll_sort_wrapper(M.sort_type_desc) end)

------------------------
--- Diagnostic Sorts ---
------------------------

vim.keymap.set("n", "<leader>qoi", "<nop>")

local severity_map = {
    E = 1,
    W = 2,
    I = 3,
    H = 4,
} ---@type table<string, integer>

function M.sort_severity_asc(a, b)
    if (not a) or not b then return false end

    if a.type and b.type then
        local severity_a = severity_map[a.type] or nil
        local severity_b = severity_map[b.type] or nil

        if (severity_a and severity_b) and severity_a ~= severity_b then
            return severity_a < severity_b
        end
    end

    if a.bufnr and b.bufnr then
        local fname_a = vim.fn.bufname(a.bufnr)
        local fname_b = vim.fn.bufname(b.bufnr)

        if (fname_a and fname_b) and fname_a ~= fname_b then return fname_a < fname_b end
    end

    if (a.lnum and b.lnum) and a.lnum ~= b.lnum then return a.lnum < b.lnum end
    if (a.col and b.col) and a.col ~= b.col then return a.col < b.col end
    if (a.end_lnum and b.end_lnum) and a.end_lnum ~= b.end_lnum then
        return a.end_lnum < b.end_lnum
    end
    if (a.end_col and b.end_col) and a.end_col ~= b.end_col then return a.end_col < b.end_col end

    return false
end

function M.sort_severity_desc(a, b)
    if (not a) or not b then return false end

    if a.type and b.type then
        local severity_a = severity_map[a.type] or nil
        local severity_b = severity_map[b.type] or nil

        if (severity_a and severity_b) and severity_a ~= severity_b then
            return severity_a > severity_b
        end
    end

    if a.bufnr and b.bufnr then
        local fname_a = vim.fn.bufname(a.bufnr)
        local fname_b = vim.fn.bufname(b.bufnr)

        if (fname_a and fname_b) and fname_a ~= fname_b then return fname_a > fname_b end
    end

    if (a.lnum and b.lnum) and a.lnum ~= b.lnum then return a.lnum > b.lnum end
    if (a.col and b.col) and a.col ~= b.col then return a.col > b.col end
    if (a.end_lnum and b.end_lnum) and a.end_lnum ~= b.end_lnum then
        return a.end_lnum > b.end_lnum
    end
    if (a.end_col and b.end_col) and a.end_col ~= b.end_col then return a.end_col > b.end_col end

    return false
end

vim.keymap.set("n", "<leader>qois", function() M.qf_sort_wrapper(M.sort_severity_asc) end)
vim.keymap.set("n", "<leader>qoiS", function() M.qf_sort_wrapper(M.sort_severity_desc) end)
vim.keymap.set("n", "<leader>lois", function() M.ll_sort_wrapper(M.sort_severity_asc) end)
vim.keymap.set("n", "<leader>loiS", function() M.ll_sort_wrapper(M.sort_severity_desc) end)

function M.sort_diag_fname_asc(a, b)
    if (not a) or not b then return false end

    if a.bufnr and b.bufnr then
        local fname_a = vim.fn.bufname(a.bufnr)
        local fname_b = vim.fn.bufname(b.bufnr)

        if (fname_a and fname_b) and fname_a ~= fname_b then return fname_a < fname_b end
    end

    if a.type and b.type then
        local severity_a = severity_map[a.type] or nil
        local severity_b = severity_map[b.type] or nil

        if (severity_a and severity_b) and severity_a ~= severity_b then
            return severity_a < severity_b
        end
    end

    if (a.lnum and b.lnum) and a.lnum ~= b.lnum then return a.lnum < b.lnum end
    if (a.col and b.col) and a.col ~= b.col then return a.col < b.col end
    if (a.end_lnum and b.end_lnum) and a.end_lnum ~= b.end_lnum then
        return a.end_lnum < b.end_lnum
    end
    if (a.end_col and b.end_col) and a.end_col ~= b.end_col then return a.end_col < b.end_col end

    return false
end

function M.sort_diag_fname_desc(a, b)
    if (not a) or not b then return false end

    if a.bufnr and b.bufnr then
        local fname_a = vim.fn.bufname(a.bufnr)
        local fname_b = vim.fn.bufname(b.bufnr)

        if (fname_a and fname_b) and fname_a ~= fname_b then return fname_a > fname_b end
    end

    if a.type and b.type then
        local severity_a = severity_map[a.type] or nil
        local severity_b = severity_map[b.type] or nil

        if (severity_a and severity_b) and severity_a ~= severity_b then
            return severity_a > severity_b
        end
    end

    if (a.lnum and b.lnum) and a.lnum ~= b.lnum then return a.lnum > b.lnum end
    if (a.col and b.col) and a.col ~= b.col then return a.col > b.col end
    if (a.end_lnum and b.end_lnum) and a.end_lnum ~= b.end_lnum then
        return a.end_lnum > b.end_lnum
    end
    if (a.end_col and b.end_col) and a.end_col ~= b.end_col then return a.end_col > b.end_col end

    return false
end

vim.keymap.set("n", "<leader>qoif", function() M.qf_sort_wrapper(M.sort_diag_fname_asc) end)
vim.keymap.set("n", "<leader>qoiF", function() M.qf_sort_wrapper(M.sort_diag_fname_desc) end)
vim.keymap.set("n", "<leader>loif", function() M.ll_sort_wrapper(M.sort_diag_fname_asc) end)
vim.keymap.set("n", "<leader>loiF", function() M.ll_sort_wrapper(M.sort_diag_fname_desc) end)

return M
