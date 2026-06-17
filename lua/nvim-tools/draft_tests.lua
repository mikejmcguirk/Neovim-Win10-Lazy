local M = {}

local ntl = require("nvim-tools.list")

function M.test_keep_rm_while()
    local orig_list = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }

    -----------------------
    -- Keep In Place Fwd --
    -----------------------

    -- Middle idx

    local foo = ntl.copy(orig_list)
    ntl.keep_while(foo, function(x)
        return x <= 3
    end)

    assert(vim.deep_equal(foo, { 1, 2, 3 }))

    foo = ntl.copy(orig_list)
    ntl.keep_while(foo, function(x)
        return x >= 3
    end)

    assert(vim.deep_equal(foo, {}))

    -- Bottom Idx

    foo = ntl.copy(orig_list)
    ntl.keep_while(foo, function(x)
        return x <= 1
    end)

    assert(vim.deep_equal(foo, { 1 }))

    foo = ntl.copy(orig_list)
    ntl.keep_while(foo, function(x)
        return x >= 1
    end)

    assert(vim.deep_equal(foo, orig_list))

    -- Zero Idx

    foo = ntl.copy(orig_list)
    ntl.keep_while(foo, function(x)
        return x <= 0
    end)

    assert(vim.deep_equal(foo, {}))

    foo = ntl.copy(orig_list)
    ntl.keep_while(foo, function(x)
        return x >= 0
    end)

    assert(vim.deep_equal(foo, orig_list))

    -- Top Idx

    foo = ntl.copy(orig_list)
    ntl.keep_while(foo, function(x)
        return x <= 10
    end)

    assert(vim.deep_equal(foo, orig_list))

    foo = ntl.copy(orig_list)
    ntl.keep_while(foo, function(x)
        return x >= 10
    end)

    assert(vim.deep_equal(foo, {}))

    -- Over Idx

    foo = ntl.copy(orig_list)
    ntl.keep_while(foo, function(x)
        return x <= 11
    end)

    assert(vim.deep_equal(foo, orig_list))

    foo = ntl.copy(orig_list)
    ntl.keep_while(foo, function(x)
        return x >= 11
    end)

    assert(vim.deep_equal(foo, {}))

    -----------------------
    -- Keep In Place Rev --
    -----------------------

    -- Middle idx

    foo = ntl.copy(orig_list)
    ntl.keep_while(foo, function(x)
        return x <= 3
    end, true)

    assert(vim.deep_equal(foo, {}))

    foo = ntl.copy(orig_list)
    ntl.keep_while(foo, function(x)
        return x >= 3
    end, true)

    assert(vim.deep_equal(foo, { 3, 4, 5, 6, 7, 8, 9, 10 }))

    -- Bottom Idx

    foo = ntl.copy(orig_list)
    ntl.keep_while(foo, function(x)
        return x <= 1
    end, true)

    assert(vim.deep_equal(foo, {}))

    foo = ntl.copy(orig_list)
    ntl.keep_while(foo, function(x)
        return x >= 1
    end, true)

    assert(vim.deep_equal(foo, orig_list))

    -- Zero Idx

    foo = ntl.copy(orig_list)
    ntl.keep_while(foo, function(x)
        return x <= 0
    end, true)

    assert(vim.deep_equal(foo, {}))

    foo = ntl.copy(orig_list)
    ntl.keep_while(foo, function(x)
        return x >= 0
    end, true)

    assert(vim.deep_equal(foo, orig_list))

    -- Top Idx

    foo = ntl.copy(orig_list)
    ntl.keep_while(foo, function(x)
        return x <= 10
    end, true)

    assert(vim.deep_equal(foo, orig_list))

    foo = ntl.copy(orig_list)
    ntl.keep_while(foo, function(x)
        return x >= 10
    end, true)

    assert(vim.deep_equal(foo, { 10 }))

    -- Over Idx

    foo = ntl.copy(orig_list)
    ntl.keep_while(foo, function(x)
        return x <= 11
    end, true)

    assert(vim.deep_equal(foo, orig_list))

    foo = ntl.copy(orig_list)
    ntl.keep_while(foo, function(x)
        return x >= 11
    end, true)

    assert(vim.deep_equal(foo, {}))

    -----------------------
    -- Rm In Place Fwd --
    -----------------------

    -- Middle idx

    foo = ntl.copy(orig_list)
    ntl.rm_while(foo, function(x)
        return x <= 3
    end)

    assert(vim.deep_equal(foo, { 4, 5, 6, 7, 8, 9, 10 }))

    foo = ntl.copy(orig_list)
    ntl.rm_while(foo, function(x)
        return x >= 3
    end)

    assert(
        vim.deep_equal(foo, orig_list),
        "Expected: " .. vim.inspect(orig_list) .. ", Actual: " .. vim.inspect(foo)
    )

    -- Bottom Idx

    foo = ntl.copy(orig_list)
    ntl.rm_while(foo, function(x)
        return x <= 1
    end)

    assert(vim.deep_equal(foo, { 2, 3, 4, 5, 6, 7, 8, 9, 10 }))

    foo = ntl.copy(orig_list)
    ntl.rm_while(foo, function(x)
        return x >= 1
    end)

    assert(vim.deep_equal(foo, {}))

    -- Zero Idx

    foo = ntl.copy(orig_list)
    ntl.rm_while(foo, function(x)
        return x <= 0
    end)

    assert(vim.deep_equal(foo, orig_list))

    foo = ntl.copy(orig_list)
    ntl.rm_while(foo, function(x)
        return x >= 0
    end)

    assert(vim.deep_equal(foo, {}))

    -- Top Idx

    foo = ntl.copy(orig_list)
    ntl.rm_while(foo, function(x)
        return x <= 10
    end)

    assert(vim.deep_equal(foo, {}))

    foo = ntl.copy(orig_list)
    ntl.rm_while(foo, function(x)
        return x >= 10
    end)

    assert(vim.deep_equal(foo, { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }))

    -- Over Idx

    foo = ntl.copy(orig_list)
    ntl.rm_while(foo, function(x)
        return x <= 11
    end)

    assert(vim.deep_equal(foo, {}))

    foo = ntl.copy(orig_list)
    ntl.rm_while(foo, function(x)
        return x >= 11
    end)

    assert(vim.deep_equal(foo, orig_list))

    -----------------------
    -- Rm In Place Rev --
    -----------------------

    -- Middle idx

    foo = ntl.copy(orig_list)
    ntl.rm_while(foo, function(x)
        return x <= 3
    end, true)

    assert(vim.deep_equal(foo, orig_list))

    foo = ntl.copy(orig_list)
    ntl.rm_while(foo, function(x)
        return x >= 3
    end, true)

    assert(vim.deep_equal(foo, { 1, 2 }))

    -- Bottom Idx

    foo = ntl.copy(orig_list)
    ntl.rm_while(foo, function(x)
        return x <= 1
    end, true)

    assert(vim.deep_equal(foo, orig_list))

    foo = ntl.copy(orig_list)
    ntl.rm_while(foo, function(x)
        return x >= 1
    end, true)

    assert(vim.deep_equal(foo, {}))

    -- Zero Idx

    foo = ntl.copy(orig_list)
    ntl.rm_while(foo, function(x)
        return x <= 0
    end, true)

    assert(vim.deep_equal(foo, orig_list))

    foo = ntl.copy(orig_list)
    ntl.rm_while(foo, function(x)
        return x >= 0
    end, true)

    assert(vim.deep_equal(foo, {}))

    -- Top Idx

    foo = ntl.copy(orig_list)
    ntl.rm_while(foo, function(x)
        return x <= 10
    end, true)

    assert(vim.deep_equal(foo, {}))

    foo = ntl.copy(orig_list)
    ntl.rm_while(foo, function(x)
        return x >= 10
    end, true)

    assert(vim.deep_equal(foo, { 1, 2, 3, 4, 5, 6, 7, 8, 9 }))

    -- Over Idx

    foo = ntl.copy(orig_list)
    ntl.rm_while(foo, function(x)
        return x <= 11
    end, true)

    assert(vim.deep_equal(foo, {}))

    foo = ntl.copy(orig_list)
    ntl.rm_while(foo, function(x)
        return x >= 11
    end, true)

    assert(vim.deep_equal(foo, orig_list))

    ------------------
    -- New List Fwd --
    ------------------

    foo = ntl.copy(orig_list)

    -- Middle idx

    local bar = ntl.keep_while_to(foo, function(x)
        return x <= 3
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, { 1, 2, 3 }))

    bar = ntl.keep_while_to(foo, function(x)
        return x >= 3
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    -- Bottom Idx

    bar = ntl.keep_while_to(foo, function(x)
        return x <= 1
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, { 1 }))

    bar = ntl.keep_while_to(foo, function(x)
        return x >= 1
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, orig_list))

    -- Zero Idx

    bar = ntl.keep_while_to(foo, function(x)
        return x <= 0
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    bar = ntl.keep_while_to(foo, function(x)
        return x >= 0
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, orig_list))

    -- Top Idx

    bar = ntl.keep_while_to(foo, function(x)
        return x <= 10
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, orig_list))

    bar = ntl.keep_while_to(foo, function(x)
        return x >= 10
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    -- Over Idx

    bar = ntl.keep_while_to(foo, function(x)
        return x <= 11
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, orig_list))

    bar = ntl.keep_while_to(foo, function(x)
        return x >= 11
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    ------------------
    -- New List Rev --
    ------------------

    -- Middle idx

    bar = ntl.keep_while_to(foo, function(x)
        return x <= 3
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    bar = ntl.keep_while_to(foo, function(x)
        return x >= 3
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, { 3, 4, 5, 6, 7, 8, 9, 10 }))

    -- Bottom Idx

    bar = ntl.keep_while_to(foo, function(x)
        return x <= 1
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    bar = ntl.keep_while_to(foo, function(x)
        return x >= 1
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, orig_list))

    -- Zero Idx

    bar = ntl.keep_while_to(foo, function(x)
        return x <= 0
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    bar = ntl.keep_while_to(foo, function(x)
        return x >= 0
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, orig_list))

    -- Top Idx

    bar = ntl.keep_while_to(foo, function(x)
        return x <= 10
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, orig_list))

    bar = ntl.keep_while_to(foo, function(x)
        return x >= 10
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, { 10 }))

    -- Over Idx

    bar = ntl.keep_while_to(foo, function(x)
        return x <= 11
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, orig_list))

    bar = ntl.keep_while_to(foo, function(x)
        return x >= 11
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    ---------------------
    -- Rm New List Fwd --
    ---------------------

    -- Middle idx

    bar = ntl.rm_while_to(foo, function(x)
        return x <= 3
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, { 4, 5, 6, 7, 8, 9, 10 }))

    bar = ntl.rm_while_to(foo, function(x)
        return x >= 3
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, orig_list))

    -- Bottom Idx

    bar = ntl.rm_while_to(foo, function(x)
        return x <= 1
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, { 2, 3, 4, 5, 6, 7, 8, 9, 10 }))

    bar = ntl.rm_while_to(foo, function(x)
        return x >= 1
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    -- Zero Idx

    bar = ntl.rm_while_to(foo, function(x)
        return x <= 0
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, orig_list))

    bar = ntl.rm_while_to(foo, function(x)
        return x >= 0
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    -- Top Idx

    bar = ntl.rm_while_to(foo, function(x)
        return x <= 10
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    bar = ntl.rm_while_to(foo, function(x)
        return x >= 10
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }))

    -- Over Idx

    bar = ntl.rm_while_to(foo, function(x)
        return x <= 11
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    bar = ntl.rm_while_to(foo, function(x)
        return x >= 11
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, orig_list))

    ---------------------
    -- Rm New List Rev --
    ---------------------

    -- Middle idx

    bar = ntl.rm_while_to(foo, function(x)
        return x <= 3
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, orig_list))

    bar = ntl.rm_while_to(foo, function(x)
        return x >= 3
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, { 1, 2 }))

    -- Bottom Idx

    bar = ntl.rm_while_to(foo, function(x)
        return x <= 1
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, orig_list))

    bar = ntl.rm_while_to(foo, function(x)
        return x >= 1
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    -- Zero Idx

    bar = ntl.rm_while_to(foo, function(x)
        return x <= 0
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, orig_list))

    bar = ntl.rm_while_to(foo, function(x)
        return x >= 0
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    -- Top Idx

    bar = ntl.rm_while_to(foo, function(x)
        return x <= 10
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    bar = ntl.rm_while_to(foo, function(x)
        return x >= 10
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, { 1, 2, 3, 4, 5, 6, 7, 8, 9 }))

    -- Over Idx

    bar = ntl.rm_while_to(foo, function(x)
        return x <= 11
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    bar = ntl.rm_while_to(foo, function(x)
        return x >= 11
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, orig_list))
end

return M
