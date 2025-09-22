-- qQ - chistory
-- <leader>q[/] - wrapping colder/cnewer

local M = {}

local function wrapping_add(x, y, min_val, max_val)
    local period = max_val - min_val + 1
    return ((x - min_val + y) % period) + min_val
end

local function wrapping_sub(x, y, min_val, max_val)
    local period = max_val - min_val + 1
    return ((x - y - min_val) % period) + min_val
end

-- TODO: Test on an empty qf list, both to see how counts/base work and also for error handling
function M.q_older(count)
    local cur_stack_nr = vim.fn.getqflist({ nr = 0 }).nr
    local stack_len = vim.fn.getqflist({ nr = "$" }).nr
    local new_stack_nr = wrapping_sub(cur_stack_nr, count, 1, stack_len)
    vim.api.nvim_cmd({ cmd = "chistory", count = new_stack_nr }, {})
    local elo = require("mjm.error-list-open")
    elo.resize_qflist()
end

-----------------
--- Plug Maps ---
-----------------

vim.api.nvim_set_keymap("n", "<Plug>(qf-rancher-qf-older)", "<nop>", {
    noremap = true,
    desc = "<Plug> Go to an older qflist",
    callback = function()
        M.q_older(vim.v.count1)
    end,
})

return M
