--- TODO:
--- - Check that all functions have reasonable default sorts
--- - Check that window height updates are triggered where appropriate
--- - Check that functions have proper visibility
--- - Check that all mappings have plugs and cmds
--- - Check that all maps/cmds/plugs have desc fieldss
--- - Check that all functions have annotations and documentation
--- - Check that the qf and loclist versions are both properly built for purpose. Should be able
---     to use the loclist function for buf/win specific info

-- TODO: The hotkeys here need to line up with the filter functions and the get functions
-- TODO: Do I resize on sort?

local M = {}

vim.keymap.set("n", "<leader>qt", "<nop>")
vim.keymap.set("n", "<leader>lt", "<nop>")

---------------------
--- Wrapper Funcs ---
---------------------

-- TODO: With the getlist and setlist funcs, I think these can be consolidated into
-- one piece of logic. Tough though because we do need to do the loclist check here

function M.qf_sort_wrapper(sort_func)
    local list_size = vim.fn.getqflist({ size = true }).size --- @type integer
    if (not list_size) or list_size == 0 then
        vim.api.nvim_echo({ { "No list entries", "" } }, false, {})
        return
    end

    if list_size == 1 then
        return
    end

    local list_nr = (function()
        if vim.v.count > 0 then
            return math.min(vim.v.count, vim.fn.getqflist({ nr = "$" }).nr)
        else
            return vim.fn.getqflist({ nr = 0 }).nr
        end
    end)() --- @type integer

    local qf_win = (function()
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            if vim.fn.win_gettype(win) == "quickfix" then
                return win
            end
        end

        return nil
    end)() --- @type integer

    local view = qf_win and vim.api.nvim_win_call(qf_win, vim.fn.winsaveview) or nil

    local list = vim.fn.getqflist({ nr = list_nr, items = true }) --- @type table
    table.sort(list.items, sort_func)
    vim.fn.setqflist({}, "r", { nr = list_nr, items = list.items })

    if qf_win and view then
        view.topline = math.max(view.topline, 0)
        vim.api.nvim_win_call(qf_win, function()
            vim.fn.winrestview(view)
        end)
    end
end

function M.ll_sort_wrapper(sort_func)
    local cur_win = vim.api.nvim_get_current_win()

    local list_size = vim.fn.getloclist(cur_win, { size = true }).size --- @type integer
    if (not list_size) or list_size == 0 then
        vim.api.nvim_echo({ { "No list entries", "" } }, false, {})
        return
    end

    if list_size == 1 then
        return
    end

    local list_nr = (function()
        if vim.v.count > 0 then
            return math.min(vim.v.count, vim.fn.getloclist(cur_win, { nr = "$" }).nr)
        else
            return vim.fn.getloclist(cur_win, { nr = 0 }).nr
        end
    end)() --- @type integer

    local loclist_win = (function()
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            if vim.fn.win_gettype(win) == "loclist" then
                return win
            end
        end

        return nil
    end)() --- @type integer

    local view = loclist_win and vim.api.nvim_win_call(loclist_win, vim.fn.winsaveview) or nil

    local list = vim.fn.getloclist(cur_win, { nr = list_nr, items = true }) --- @type table
    table.sort(list.items, sort_func)
    vim.fn.setloclist(cur_win, {}, "r", { nr = list_nr, items = list.items })

    if loclist_win and view then
        view.topline = math.max(view.topline, 0)
        vim.api.nvim_win_call(loclist_win, function()
            vim.fn.winrestview(view)
        end)
    end
end

-------------------
--- Basic Sorts ---
-------------------

-- TODO: Do I underline the sort wrappers? Not sure if I want to make guarantees about these
-- TODO: probably outline the line number checks, since you can just return false

function M.sort_fname_asc(a, b)
    if (not a) or not b then
        return false
    end

    if a.bufnr and b.bufnr then
        local fname_a = vim.fn.bufname(a.bufnr)
        local fname_b = vim.fn.bufname(b.bufnr)

        if (fname_a and fname_b) and fname_a ~= fname_b then
            return fname_a < fname_b
        end
    end

    if (a.lnum and b.lnum) and a.lnum ~= b.lnum then
        return a.lnum < b.lnum
    end
    if (a.col and b.col) and a.col ~= b.col then
        return a.col < b.col
    end
    if (a.end_lnum and b.end_lnum) and a.end_lnum ~= b.end_lnum then
        return a.end_lnum < b.end_lnum
    end
    if (a.end_col and b.end_col) and a.end_col ~= b.end_col then
        return a.end_col < b.end_col
    end

    return false
end

function M.sort_fname_desc(a, b)
    if (not a) or not b then
        return false
    end

    if a.bufnr and b.bufnr then
        local fname_a = vim.fn.bufname(a.bufnr)
        local fname_b = vim.fn.bufname(b.bufnr)

        if (fname_a and fname_b) and fname_a ~= fname_b then
            return fname_a < fname_b
        end
    end

    if (a.lnum and b.lnum) and a.lnum ~= b.lnum then
        return a.lnum > b.lnum
    end
    if (a.col and b.col) and a.col ~= b.col then
        return a.col > b.col
    end
    if (a.end_lnum and b.end_lnum) and a.end_lnum ~= b.end_lnum then
        return a.end_lnum > b.end_lnum
    end
    if (a.end_col and b.end_col) and a.end_col ~= b.end_col then
        return a.end_col > b.end_col
    end

    return false
end

vim.keymap.set("n", "<leader>qtf", function()
    M.qf_sort_wrapper(M.sort_fname_asc)
end)
vim.keymap.set("n", "<leader>qtF", function()
    M.qf_sort_wrapper(M.sort_fname_desc)
end)
vim.keymap.set("n", "<leader>ltf", function()
    M.ll_sort_wrapper(M.sort_fname_asc)
end)
vim.keymap.set("n", "<leader>ltF", function()
    M.ll_sort_wrapper(M.sort_fname_desc)
end)

function M.sort_type_asc(a, b)
    if (not a) or not b then
        return false
    end

    if (a.type and b.type) and a.type ~= b.type then
        return a.type < b.type
    end

    if a.bufnr and b.bufnr then
        local fname_a = vim.fn.bufname(a.bufnr)
        local fname_b = vim.fn.bufname(b.bufnr)

        if (fname_a and fname_b) and fname_a ~= fname_b then
            return fname_a < fname_b
        end
    end

    if (a.lnum and b.lnum) and a.lnum ~= b.lnum then
        return a.lnum < b.lnum
    end
    if (a.col and b.col) and a.col ~= b.col then
        return a.col < b.col
    end
    if (a.end_lnum and b.end_lnum) and a.end_lnum ~= b.end_lnum then
        return a.end_lnum < b.end_lnum
    end
    if (a.end_col and b.end_col) and a.end_col ~= b.end_col then
        return a.end_col < b.end_col
    end

    return false
end

function M.sort_type_desc(a, b)
    if (not a) or not b then
        return false
    end

    if (a.type and b.type) and a.type ~= b.type then
        return a.type > b.type
    end

    if a.bufnr and b.bufnr then
        local fname_a = vim.fn.bufname(a.bufnr)
        local fname_b = vim.fn.bufname(b.bufnr)

        if (fname_a and fname_b) and fname_a ~= fname_b then
            return fname_a > fname_b
        end
    end

    if (a.lnum and b.lnum) and a.lnum ~= b.lnum then
        return a.lnum > b.lnum
    end
    if (a.col and b.col) and a.col ~= b.col then
        return a.col > b.col
    end
    if (a.end_lnum and b.end_lnum) and a.end_lnum ~= b.end_lnum then
        return a.end_lnum > b.end_lnum
    end
    if (a.end_col and b.end_col) and a.end_col ~= b.end_col then
        return a.end_col > b.end_col
    end

    return false
end

vim.keymap.set("n", "<leader>qtt", function()
    M.qf_sort_wrapper(M.sort_type_asc)
end)
vim.keymap.set("n", "<leader>qtT", function()
    M.qf_sort_wrapper(M.sort_type_desc)
end)
vim.keymap.set("n", "<leader>ltt", function()
    M.ll_sort_wrapper(M.sort_type_asc)
end)
vim.keymap.set("n", "<leader>ltT", function()
    M.ll_sort_wrapper(M.sort_type_desc)
end)

------------------------
--- Diagnostic Sorts ---
------------------------

vim.keymap.set("n", "<leader>qti", "<nop>")
vim.keymap.set("n", "<leader>lti", "<nop>")

local severity_unmap = {
    E = vim.diagnostic.severity.ERROR,
    W = vim.diagnostic.severity.WARN,
    I = vim.diagnostic.severity.INFO,
    H = vim.diagnostic.severity.HINT,
} ---@type table<string, integer>

function M.sort_severity_asc(a, b)
    if (not a) or not b then
        return false
    end

    if a.type and b.type then
        local severity_a = severity_unmap[a.type] or nil
        local severity_b = severity_unmap[b.type] or nil

        if (severity_a and severity_b) and severity_a ~= severity_b then
            return severity_a < severity_b
        end
    end

    if a.bufnr and b.bufnr then
        local fname_a = vim.fn.bufname(a.bufnr)
        local fname_b = vim.fn.bufname(b.bufnr)

        if (fname_a and fname_b) and fname_a ~= fname_b then
            return fname_a < fname_b
        end
    end

    if (a.lnum and b.lnum) and a.lnum ~= b.lnum then
        return a.lnum < b.lnum
    end
    if (a.col and b.col) and a.col ~= b.col then
        return a.col < b.col
    end
    if (a.end_lnum and b.end_lnum) and a.end_lnum ~= b.end_lnum then
        return a.end_lnum < b.end_lnum
    end
    if (a.end_col and b.end_col) and a.end_col ~= b.end_col then
        return a.end_col < b.end_col
    end

    return false
end

function M.sort_severity_desc(a, b)
    if (not a) or not b then
        return false
    end

    if a.type and b.type then
        local severity_a = severity_unmap[a.type] or nil
        local severity_b = severity_unmap[b.type] or nil
        if (severity_a and severity_b) and severity_a ~= severity_b then
            return severity_a > severity_b
        end
    end

    if a.bufnr and b.bufnr then
        local fname_a = vim.fn.bufname(a.bufnr)
        local fname_b = vim.fn.bufname(b.bufnr)
        if (fname_a and fname_b) and fname_a ~= fname_b then
            return fname_a > fname_b
        end
    end

    if (a.lnum and b.lnum) and a.lnum ~= b.lnum then
        return a.lnum > b.lnum
    end

    if (a.col and b.col) and a.col ~= b.col then
        return a.col > b.col
    end

    if (a.end_lnum and b.end_lnum) and a.end_lnum ~= b.end_lnum then
        return a.end_lnum > b.end_lnum
    end

    if (a.end_col and b.end_col) and a.end_col ~= b.end_col then
        return a.end_col > b.end_col
    end

    return false
end

vim.keymap.set("n", "<leader>qtis", function()
    M.qf_sort_wrapper(M.sort_severity_asc)
end)

vim.keymap.set("n", "<leader>qtiS", function()
    M.qf_sort_wrapper(M.sort_severity_desc)
end)

vim.keymap.set("n", "<leader>ltis", function()
    M.ll_sort_wrapper(M.sort_severity_asc)
end)

vim.keymap.set("n", "<leader>ltiS", function()
    M.ll_sort_wrapper(M.sort_severity_desc)
end)

function M.sort_diag_fname_asc(a, b)
    if (not a) or not b then
        return false
    end

    if a.bufnr and b.bufnr then
        local fname_a = vim.fn.bufname(a.bufnr)
        local fname_b = vim.fn.bufname(b.bufnr)
        if (fname_a and fname_b) and fname_a ~= fname_b then
            return fname_a < fname_b
        end
    end

    if (a.lnum and b.lnum) and a.lnum ~= b.lnum then
        return a.lnum < b.lnum
    end

    if (a.col and b.col) and a.col ~= b.col then
        return a.col < b.col
    end

    if (a.end_lnum and b.end_lnum) and a.end_lnum ~= b.end_lnum then
        return a.end_lnum < b.end_lnum
    end

    if (a.end_col and b.end_col) and a.end_col ~= b.end_col then
        return a.end_col < b.end_col
    end

    if a.type and b.type then
        local severity_a = severity_unmap[a.type] or 4
        local severity_b = severity_unmap[b.type] or 4
        if (severity_a and severity_b) and severity_a ~= severity_b then
            return severity_a < severity_b
        end
    end

    return false
end

function M.sort_diag_fname_desc(a, b)
    if (not a) or not b then
        return false
    end

    if a.bufnr and b.bufnr then
        local fname_a = vim.fn.bufname(a.bufnr)
        local fname_b = vim.fn.bufname(b.bufnr)
        if (fname_a and fname_b) and fname_a ~= fname_b then
            return fname_a > fname_b
        end
    end

    if (a.lnum and b.lnum) and a.lnum ~= b.lnum then
        return a.lnum > b.lnum
    end

    if (a.col and b.col) and a.col ~= b.col then
        return a.col > b.col
    end

    if (a.end_lnum and b.end_lnum) and a.end_lnum ~= b.end_lnum then
        return a.end_lnum > b.end_lnum
    end

    if (a.end_col and b.end_col) and a.end_col ~= b.end_col then
        return a.end_col > b.end_col
    end

    if a.type and b.type then
        local severity_a = severity_unmap[a.type] or 4
        local severity_b = severity_unmap[b.type] or 4
        if (severity_a and severity_b) and severity_a ~= severity_b then
            return severity_a > severity_b
        end
    end

    return false
end

vim.keymap.set("n", "<leader>qtif", function()
    M.qf_sort_wrapper(M.sort_diag_fname_asc)
end)

vim.keymap.set("n", "<leader>qtiF", function()
    M.qf_sort_wrapper(M.sort_diag_fname_desc)
end)

vim.keymap.set("n", "<leader>ltif", function()
    M.ll_sort_wrapper(M.sort_diag_fname_asc)
end)

vim.keymap.set("n", "<leader>ltiF", function()
    M.ll_sort_wrapper(M.sort_diag_fname_desc)
end)

return M
