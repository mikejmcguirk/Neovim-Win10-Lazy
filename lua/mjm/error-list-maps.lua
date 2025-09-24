local map = function(mode, lhs, rhs, desc)
    vim.api.nvim_set_keymap(mode, lhs, rhs, {
        noremap = true,
        desc = desc,
    })
end
-------------------------
--- OPEN/CLOSE/TOGGLE ---
-------------------------

map("n", "<leader>q", "<nop>", "Prevent fallback to other mappings")
map("n", "<leader>l", "<nop>", "Prevent fallback to other mappings")

map("n", "<leader>qp", "<Plug>(qf-rancher-open-qf-list)", "Open the quickfix list")
map("n", "<leader>qo", "<Plug>(qf-rancher-close-qf-list)", "Close the quickfix list")
map("n", "<leader>qq", "<Plug>(qf-rancher-toggle-qf-list)", "Toggle the quickfix list")

map("n", "<leader>lp", "<Plug>(qf-rancher-open-loclist)", "Open the location list")
map("n", "<leader>lo", "<Plug>(qf-rancher-close-loclist)", "Close the location list")
map("n", "<leader>ll", "<Plug>(qf-rancher-toggle-loclist)", "Toggle the location list")

------------------
--- NAV ACTION ---
------------------

map("n", "[q", "<Plug>(qf-rancher-qf-prev)", "Go to a previous qf entry")
map("n", "]q", "<Plug>(qf-rancher-qf-next)", "Go to a later qf entry")
map("n", "[<C-q>", "<Plug>(qf-rancher-qf-pfile)", "Go to the previous qf file")
map("n", "]<C-q>", "<Plug>(qf-rancher-qf-nfile)", "Go to the next qf file")
map("n", "<leader>q<C-q>", "<Plug>(qf-rancher-qf-jump)", "Jump to the qflist")

map("n", "[l", "<Plug>(qf-rancher-ll-prev)", "Go to a previous loclist entry")
map("n", "]l", "<Plug>(qf-rancher-ll-next)", "Go to a previous loclist entry")
map("n", "[<C-l>", "<Plug>(qf-rancher-ll-pfile)", "Go to the previous loclist file")
map("n", "]<C-l>", "<Plug>(qf-rancher-ll-nfile)", "Go to the next loclist file")
map("n", "<leader>l<C-l>", "<Plug>(qf-rancher-ll-jump)", "Jump to the loclist")

-------------
--- STACK ---
-------------

map("n", "<leader>q[", "<Plug>(qf-rancher-qf-older)", "Go to an older qflist")
map("n", "<leader>q]", "<Plug>(qf-rancher-qf-newer)", "Go to a newer qflist")
map("n", "<leader>qQ", "<Plug>(qf-rancher-qf-history)", "View or jump within the quickfix history")
map("n", "<leader>qe", "<Plug>(qf-rancher-qf-del)", "Delete a list from the quickfix stack")
map("n", "<leader>qE", "<Plug>(qf-rancher-qf-del-all)", "Delete all items from the quickfix stack")

map("n", "<leader>l[", "<Plug>(qf-rancher-ll-older)", "Go to an older loclist")
map("n", "<leader>l]", "<Plug>(qf-rancher-ll-newer)", "Go to a newer loclist")
map("n", "<leader>lL", "<Plug>(qf-rancher-ll-history)", "View or jump within the loclist history")
map("n", "<leader>le", "<Plug>(qf-rancher-ll-del)", "Delete a list from the loclist stack")
map("n", "<leader>lE", "<Plug>(qf-rancher-ll-del-all)", "Delete all items from the loclist stack")
