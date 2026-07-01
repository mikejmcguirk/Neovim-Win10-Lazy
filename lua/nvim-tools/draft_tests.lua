local M = {}

local ntt = require("nvim-tools.table")

function M.test_keep_rm_while()
    local orig_list = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }

    -----------------------
    -- Keep In Place Fwd --
    -----------------------

    -- Middle idx

    local foo = ntt.i_copy(orig_list)
    ntt.i_keep_while(foo, function(x)
        return x <= 3
    end)

    assert(vim.deep_equal(foo, { 1, 2, 3 }))

    foo = ntt.i_copy(orig_list)
    ntt.i_keep_while(foo, function(x)
        return x >= 3
    end)

    assert(vim.deep_equal(foo, {}))

    -- Bottom Idx

    foo = ntt.i_copy(orig_list)
    ntt.i_keep_while(foo, function(x)
        return x <= 1
    end)

    assert(vim.deep_equal(foo, { 1 }))

    foo = ntt.i_copy(orig_list)
    ntt.i_keep_while(foo, function(x)
        return x >= 1
    end)

    assert(vim.deep_equal(foo, orig_list))

    -- Zero Idx

    foo = ntt.i_copy(orig_list)
    ntt.i_keep_while(foo, function(x)
        return x <= 0
    end)

    assert(vim.deep_equal(foo, {}))

    foo = ntt.i_copy(orig_list)
    ntt.i_keep_while(foo, function(x)
        return x >= 0
    end)

    assert(vim.deep_equal(foo, orig_list))

    -- Top Idx

    foo = ntt.i_copy(orig_list)
    ntt.i_keep_while(foo, function(x)
        return x <= 10
    end)

    assert(vim.deep_equal(foo, orig_list))

    foo = ntt.i_copy(orig_list)
    ntt.i_keep_while(foo, function(x)
        return x >= 10
    end)

    assert(vim.deep_equal(foo, {}))

    -- Over Idx

    foo = ntt.i_copy(orig_list)
    ntt.i_keep_while(foo, function(x)
        return x <= 11
    end)

    assert(vim.deep_equal(foo, orig_list))

    foo = ntt.i_copy(orig_list)
    ntt.i_keep_while(foo, function(x)
        return x >= 11
    end)

    assert(vim.deep_equal(foo, {}))

    -----------------------
    -- Keep In Place Rev --
    -----------------------

    -- Middle idx

    foo = ntt.i_copy(orig_list)
    ntt.i_keep_while(foo, function(x)
        return x <= 3
    end, true)

    assert(vim.deep_equal(foo, {}))

    foo = ntt.i_copy(orig_list)
    ntt.i_keep_while(foo, function(x)
        return x >= 3
    end, true)

    assert(vim.deep_equal(foo, { 3, 4, 5, 6, 7, 8, 9, 10 }))

    -- Bottom Idx

    foo = ntt.i_copy(orig_list)
    ntt.i_keep_while(foo, function(x)
        return x <= 1
    end, true)

    assert(vim.deep_equal(foo, {}))

    foo = ntt.i_copy(orig_list)
    ntt.i_keep_while(foo, function(x)
        return x >= 1
    end, true)

    assert(vim.deep_equal(foo, orig_list))

    -- Zero Idx

    foo = ntt.i_copy(orig_list)
    ntt.i_keep_while(foo, function(x)
        return x <= 0
    end, true)

    assert(vim.deep_equal(foo, {}))

    foo = ntt.i_copy(orig_list)
    ntt.i_keep_while(foo, function(x)
        return x >= 0
    end, true)

    assert(vim.deep_equal(foo, orig_list))

    -- Top Idx

    foo = ntt.i_copy(orig_list)
    ntt.i_keep_while(foo, function(x)
        return x <= 10
    end, true)

    assert(vim.deep_equal(foo, orig_list))

    foo = ntt.i_copy(orig_list)
    ntt.i_keep_while(foo, function(x)
        return x >= 10
    end, true)

    assert(vim.deep_equal(foo, { 10 }))

    -- Over Idx

    foo = ntt.i_copy(orig_list)
    ntt.i_keep_while(foo, function(x)
        return x <= 11
    end, true)

    assert(vim.deep_equal(foo, orig_list))

    foo = ntt.i_copy(orig_list)
    ntt.i_keep_while(foo, function(x)
        return x >= 11
    end, true)

    assert(vim.deep_equal(foo, {}))

    -----------------------
    -- Rm In Place Fwd --
    -----------------------

    -- Middle idx

    foo = ntt.i_copy(orig_list)
    ntt.i_discard_while(foo, function(x)
        return x <= 3
    end)

    assert(
        vim.deep_equal(foo, { 4, 5, 6, 7, 8, 9, 10 }),
        "Expected: " .. vim.inspect({ 4, 5, 6, 7, 8, 9, 10 }) .. ", Actual: " .. vim.inspect(foo)
    )

    foo = ntt.i_copy(orig_list)
    ntt.i_discard_while(foo, function(x)
        return x >= 3
    end)

    assert(
        vim.deep_equal(foo, orig_list),
        "Expected: " .. vim.inspect(orig_list) .. ", Actual: " .. vim.inspect(foo)
    )

    -- Bottom Idx

    foo = ntt.i_copy(orig_list)
    ntt.i_discard_while(foo, function(x)
        return x <= 1
    end)

    assert(vim.deep_equal(foo, { 2, 3, 4, 5, 6, 7, 8, 9, 10 }))

    foo = ntt.i_copy(orig_list)
    ntt.i_discard_while(foo, function(x)
        return x >= 1
    end)

    assert(
        vim.deep_equal({}, foo),
        "Expected: " .. vim.inspect({}) .. ", Actual: " .. vim.inspect(foo)
    )

    -- Zero Idx

    foo = ntt.i_copy(orig_list)
    ntt.i_discard_while(foo, function(x)
        return x <= 0
    end)

    assert(vim.deep_equal(foo, orig_list))

    foo = ntt.i_copy(orig_list)
    ntt.i_discard_while(foo, function(x)
        return x >= 0
    end)

    assert(vim.deep_equal(foo, {}))

    -- Top Idx

    foo = ntt.i_copy(orig_list)
    ntt.i_discard_while(foo, function(x)
        return x <= 10
    end)

    assert(vim.deep_equal(foo, {}))

    foo = ntt.i_copy(orig_list)
    ntt.i_discard_while(foo, function(x)
        return x >= 10
    end)

    assert(vim.deep_equal(foo, { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }))

    -- Over Idx

    foo = ntt.i_copy(orig_list)
    ntt.i_discard_while(foo, function(x)
        return x <= 11
    end)

    assert(vim.deep_equal(foo, {}))

    foo = ntt.i_copy(orig_list)
    ntt.i_discard_while(foo, function(x)
        return x >= 11
    end)

    assert(vim.deep_equal(foo, orig_list))

    -----------------------
    -- Rm In Place Rev --
    -----------------------

    -- Middle idx

    foo = ntt.i_copy(orig_list)
    ntt.i_discard_while(foo, function(x)
        return x <= 3
    end, true)

    assert(
        vim.deep_equal(orig_list, foo),
        "Expected: " .. vim.inspect(orig_list) .. ", Actual: " .. vim.inspect(foo)
    )

    foo = ntt.i_copy(orig_list)
    ntt.i_discard_while(foo, function(x)
        return x >= 3
    end, true)

    assert(vim.deep_equal(foo, { 1, 2 }))

    -- Bottom Idx

    foo = ntt.i_copy(orig_list)
    ntt.i_discard_while(foo, function(x)
        return x <= 1
    end, true)

    assert(vim.deep_equal(foo, orig_list))

    foo = ntt.i_copy(orig_list)
    ntt.i_discard_while(foo, function(x)
        return x >= 1
    end, true)

    assert(vim.deep_equal(foo, {}))

    -- Zero Idx

    foo = ntt.i_copy(orig_list)
    ntt.i_discard_while(foo, function(x)
        return x <= 0
    end, true)

    assert(vim.deep_equal(foo, orig_list))

    foo = ntt.i_copy(orig_list)
    ntt.i_discard_while(foo, function(x)
        return x >= 0
    end, true)

    assert(vim.deep_equal(foo, {}))

    -- Top Idx

    foo = ntt.i_copy(orig_list)
    ntt.i_discard_while(foo, function(x)
        return x <= 10
    end, true)

    assert(vim.deep_equal(foo, {}))

    foo = ntt.i_copy(orig_list)
    ntt.i_discard_while(foo, function(x)
        return x >= 10
    end, true)

    assert(vim.deep_equal(foo, { 1, 2, 3, 4, 5, 6, 7, 8, 9 }))

    -- Over Idx

    foo = ntt.i_copy(orig_list)
    ntt.i_discard_while(foo, function(x)
        return x <= 11
    end, true)

    assert(vim.deep_equal(foo, {}))

    foo = ntt.i_copy(orig_list)
    ntt.i_discard_while(foo, function(x)
        return x >= 11
    end, true)

    assert(vim.deep_equal(foo, orig_list))

    ------------------
    -- New List Fwd --
    ------------------

    foo = ntt.i_copy(orig_list)

    -- Middle idx

    local bar = ntt.i_keep_while_to(foo, function(x)
        return x <= 3
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, { 1, 2, 3 }))

    bar = ntt.i_keep_while_to(foo, function(x)
        return x >= 3
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    -- Bottom Idx

    bar = ntt.i_keep_while_to(foo, function(x)
        return x <= 1
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, { 1 }))

    bar = ntt.i_keep_while_to(foo, function(x)
        return x >= 1
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, orig_list))

    -- Zero Idx

    bar = ntt.i_keep_while_to(foo, function(x)
        return x <= 0
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    bar = ntt.i_keep_while_to(foo, function(x)
        return x >= 0
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, orig_list))

    -- Top Idx

    bar = ntt.i_keep_while_to(foo, function(x)
        return x <= 10
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, orig_list))

    bar = ntt.i_keep_while_to(foo, function(x)
        return x >= 10
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    -- Over Idx

    bar = ntt.i_keep_while_to(foo, function(x)
        return x <= 11
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, orig_list))

    bar = ntt.i_keep_while_to(foo, function(x)
        return x >= 11
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    ------------------
    -- New List Rev --
    ------------------

    -- Middle idx

    bar = ntt.i_keep_while_to(foo, function(x)
        return x <= 3
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    bar = ntt.i_keep_while_to(foo, function(x)
        return x >= 3
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, { 3, 4, 5, 6, 7, 8, 9, 10 }))

    -- Bottom Idx

    bar = ntt.i_keep_while_to(foo, function(x)
        return x <= 1
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    bar = ntt.i_keep_while_to(foo, function(x)
        return x >= 1
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, orig_list))

    -- Zero Idx

    bar = ntt.i_keep_while_to(foo, function(x)
        return x <= 0
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    bar = ntt.i_keep_while_to(foo, function(x)
        return x >= 0
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, orig_list))

    -- Top Idx

    bar = ntt.i_keep_while_to(foo, function(x)
        return x <= 10
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, orig_list))

    bar = ntt.i_keep_while_to(foo, function(x)
        return x >= 10
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, { 10 }))

    -- Over Idx

    bar = ntt.i_keep_while_to(foo, function(x)
        return x <= 11
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, orig_list))

    bar = ntt.i_keep_while_to(foo, function(x)
        return x >= 11
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    ---------------------
    -- Rm New List Fwd --
    ---------------------

    -- Middle idx

    bar = ntt.i_discard_while_to(foo, function(x)
        return x <= 3
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, { 4, 5, 6, 7, 8, 9, 10 }))

    bar = ntt.i_discard_while_to(foo, function(x)
        return x >= 3
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, orig_list))

    -- Bottom Idx

    bar = ntt.i_discard_while_to(foo, function(x)
        return x <= 1
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, { 2, 3, 4, 5, 6, 7, 8, 9, 10 }))

    bar = ntt.i_discard_while_to(foo, function(x)
        return x >= 1
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    -- Zero Idx

    bar = ntt.i_discard_while_to(foo, function(x)
        return x <= 0
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, orig_list))

    bar = ntt.i_discard_while_to(foo, function(x)
        return x >= 0
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    -- Top Idx

    bar = ntt.i_discard_while_to(foo, function(x)
        return x <= 10
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    bar = ntt.i_discard_while_to(foo, function(x)
        return x >= 10
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }))

    -- Over Idx

    bar = ntt.i_discard_while_to(foo, function(x)
        return x <= 11
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    bar = ntt.i_discard_while_to(foo, function(x)
        return x >= 11
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, orig_list))

    ---------------------
    -- Rm New List Rev --
    ---------------------

    -- Middle idx

    bar = ntt.i_discard_while_to(foo, function(x)
        return x <= 3
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, orig_list))

    bar = ntt.i_discard_while_to(foo, function(x)
        return x >= 3
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, { 1, 2 }))

    -- Bottom Idx

    bar = ntt.i_discard_while_to(foo, function(x)
        return x <= 1
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, orig_list))

    bar = ntt.i_discard_while_to(foo, function(x)
        return x >= 1
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    -- Zero Idx

    bar = ntt.i_discard_while_to(foo, function(x)
        return x <= 0
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, orig_list))

    bar = ntt.i_discard_while_to(foo, function(x)
        return x >= 0
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    -- Top Idx

    bar = ntt.i_discard_while_to(foo, function(x)
        return x <= 10
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    bar = ntt.i_discard_while_to(foo, function(x)
        return x >= 10
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, { 1, 2, 3, 4, 5, 6, 7, 8, 9 }))

    -- Over Idx

    bar = ntt.i_discard_while_to(foo, function(x)
        return x <= 11
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    bar = ntt.i_discard_while_to(foo, function(x)
        return x >= 11
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, orig_list))
end

return M
