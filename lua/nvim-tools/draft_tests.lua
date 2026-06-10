function M.test_keep_rm_while()
    local orig_list = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }

    -----------------------
    -- Keep In Place Fwd --
    -----------------------

    -- Middle idx

    local foo = M.copy(orig_list)
    M.keep_while(foo, function(x)
        return x <= 3
    end)

    assert(vim.deep_equal(foo, { 1, 2, 3 }))

    foo = M.copy(orig_list)
    M.keep_while(foo, function(x)
        return x >= 3
    end)

    assert(vim.deep_equal(foo, {}))

    -- Bottom Idx

    foo = M.copy(orig_list)
    M.keep_while(foo, function(x)
        return x <= 1
    end)

    assert(vim.deep_equal(foo, { 1 }))

    foo = M.copy(orig_list)
    M.keep_while(foo, function(x)
        return x >= 1
    end)

    assert(vim.deep_equal(foo, orig_list))

    -- Zero Idx

    foo = M.copy(orig_list)
    M.keep_while(foo, function(x)
        return x <= 0
    end)

    assert(vim.deep_equal(foo, {}))

    foo = M.copy(orig_list)
    M.keep_while(foo, function(x)
        return x >= 0
    end)

    assert(vim.deep_equal(foo, orig_list))

    -- Top Idx

    foo = M.copy(orig_list)
    M.keep_while(foo, function(x)
        return x <= 10
    end)

    assert(vim.deep_equal(foo, orig_list))

    foo = M.copy(orig_list)
    M.keep_while(foo, function(x)
        return x >= 10
    end)

    assert(vim.deep_equal(foo, {}))

    -- Over Idx

    foo = M.copy(orig_list)
    M.keep_while(foo, function(x)
        return x <= 11
    end)

    assert(vim.deep_equal(foo, orig_list))

    foo = M.copy(orig_list)
    M.keep_while(foo, function(x)
        return x >= 11
    end)

    assert(vim.deep_equal(foo, {}))

    -----------------------
    -- Keep In Place Rev --
    -----------------------

    -- Middle idx

    foo = M.copy(orig_list)
    M.keep_while(foo, function(x)
        return x <= 3
    end, true)

    assert(vim.deep_equal(foo, {}))

    foo = M.copy(orig_list)
    M.keep_while(foo, function(x)
        return x >= 3
    end, true)

    assert(vim.deep_equal(foo, { 3, 4, 5, 6, 7, 8, 9, 10 }))

    -- Bottom Idx

    foo = M.copy(orig_list)
    M.keep_while(foo, function(x)
        return x <= 1
    end, true)

    assert(vim.deep_equal(foo, {}))

    foo = M.copy(orig_list)
    M.keep_while(foo, function(x)
        return x >= 1
    end, true)

    assert(vim.deep_equal(foo, orig_list))

    -- Zero Idx

    foo = M.copy(orig_list)
    M.keep_while(foo, function(x)
        return x <= 0
    end, true)

    assert(vim.deep_equal(foo, {}))

    foo = M.copy(orig_list)
    M.keep_while(foo, function(x)
        return x >= 0
    end, true)

    assert(vim.deep_equal(foo, orig_list))

    -- Top Idx

    foo = M.copy(orig_list)
    M.keep_while(foo, function(x)
        return x <= 10
    end, true)

    assert(vim.deep_equal(foo, orig_list))

    foo = M.copy(orig_list)
    M.keep_while(foo, function(x)
        return x >= 10
    end, true)

    assert(vim.deep_equal(foo, { 10 }))

    -- Over Idx

    foo = M.copy(orig_list)
    M.keep_while(foo, function(x)
        return x <= 11
    end, true)

    assert(vim.deep_equal(foo, orig_list))

    foo = M.copy(orig_list)
    M.keep_while(foo, function(x)
        return x >= 11
    end, true)

    assert(vim.deep_equal(foo, {}))

    -----------------------
    -- Rm In Place Fwd --
    -----------------------

    -- Middle idx

    foo = M.copy(orig_list)
    M.rm_while(foo, function(x)
        return x <= 3
    end)

    assert(vim.deep_equal(foo, { 4, 5, 6, 7, 8, 9, 10 }))

    foo = M.copy(orig_list)
    M.rm_while(foo, function(x)
        return x >= 3
    end)

    assert(vim.deep_equal(foo, orig_list))

    -- Bottom Idx

    foo = M.copy(orig_list)
    M.rm_while(foo, function(x)
        return x <= 1
    end)

    assert(vim.deep_equal(foo, { 2, 3, 4, 5, 6, 7, 8, 9, 10 }))

    foo = M.copy(orig_list)
    M.rm_while(foo, function(x)
        return x >= 1
    end)

    assert(vim.deep_equal(foo, {}))

    -- Zero Idx

    foo = M.copy(orig_list)
    M.rm_while(foo, function(x)
        return x <= 0
    end)

    assert(vim.deep_equal(foo, orig_list))

    foo = M.copy(orig_list)
    M.rm_while(foo, function(x)
        return x >= 0
    end)

    assert(vim.deep_equal(foo, {}))

    -- Top Idx

    foo = M.copy(orig_list)
    M.rm_while(foo, function(x)
        return x <= 10
    end)

    assert(vim.deep_equal(foo, {}))

    foo = M.copy(orig_list)
    M.rm_while(foo, function(x)
        return x >= 10
    end)

    assert(vim.deep_equal(foo, { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }))

    -- Over Idx

    foo = M.copy(orig_list)
    M.rm_while(foo, function(x)
        return x <= 11
    end)

    assert(vim.deep_equal(foo, {}))

    foo = M.copy(orig_list)
    M.rm_while(foo, function(x)
        return x >= 11
    end)

    assert(vim.deep_equal(foo, orig_list))

    -----------------------
    -- Rm In Place Rev --
    -----------------------

    -- Middle idx

    foo = M.copy(orig_list)
    M.rm_while(foo, function(x)
        return x <= 3
    end, true)

    assert(vim.deep_equal(foo, orig_list))

    foo = M.copy(orig_list)
    M.rm_while(foo, function(x)
        return x >= 3
    end, true)

    assert(vim.deep_equal(foo, { 1, 2 }))

    -- Bottom Idx

    foo = M.copy(orig_list)
    M.rm_while(foo, function(x)
        return x <= 1
    end, true)

    assert(vim.deep_equal(foo, orig_list))

    foo = M.copy(orig_list)
    M.rm_while(foo, function(x)
        return x >= 1
    end, true)

    assert(vim.deep_equal(foo, {}))

    -- Zero Idx

    foo = M.copy(orig_list)
    M.rm_while(foo, function(x)
        return x <= 0
    end, true)

    assert(vim.deep_equal(foo, orig_list))

    foo = M.copy(orig_list)
    M.rm_while(foo, function(x)
        return x >= 0
    end, true)

    assert(vim.deep_equal(foo, {}))

    -- Top Idx

    foo = M.copy(orig_list)
    M.rm_while(foo, function(x)
        return x <= 10
    end, true)

    assert(vim.deep_equal(foo, {}))

    foo = M.copy(orig_list)
    M.rm_while(foo, function(x)
        return x >= 10
    end, true)

    assert(vim.deep_equal(foo, { 1, 2, 3, 4, 5, 6, 7, 8, 9 }))

    -- Over Idx

    foo = M.copy(orig_list)
    M.rm_while(foo, function(x)
        return x <= 11
    end, true)

    assert(vim.deep_equal(foo, {}))

    foo = M.copy(orig_list)
    M.rm_while(foo, function(x)
        return x >= 11
    end, true)

    assert(vim.deep_equal(foo, orig_list))

    ------------------
    -- New List Fwd --
    ------------------

    local foo = M.copy(orig_list)

    -- Middle idx

    local bar = M.keep_while_to(foo, function(x)
        return x <= 3
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, { 1, 2, 3 }))

    bar = M.keep_while_to(foo, function(x)
        return x >= 3
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    -- Bottom Idx

    bar = M.keep_while_to(foo, function(x)
        return x <= 1
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, { 1 }))

    bar = M.keep_while_to(foo, function(x)
        return x >= 1
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, orig_list))

    -- Zero Idx

    bar = M.keep_while_to(foo, function(x)
        return x <= 0
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    bar = M.keep_while_to(foo, function(x)
        return x >= 0
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, orig_list))

    -- Top Idx

    bar = M.keep_while_to(foo, function(x)
        return x <= 10
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, orig_list))

    bar = M.keep_while_to(foo, function(x)
        return x >= 10
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    -- Over Idx

    bar = M.keep_while_to(foo, function(x)
        return x <= 11
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, orig_list))

    bar = M.keep_while_to(foo, function(x)
        return x >= 11
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    ------------------
    -- New List Rev --
    ------------------

    -- Middle idx

    bar = M.keep_while_to(foo, function(x)
        return x <= 3
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    bar = M.keep_while_to(foo, function(x)
        return x >= 3
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, { 3, 4, 5, 6, 7, 8, 9, 10 }))

    -- Bottom Idx

    bar = M.keep_while_to(foo, function(x)
        return x <= 1
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    bar = M.keep_while_to(foo, function(x)
        return x >= 1
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, orig_list))

    -- Zero Idx

    bar = M.keep_while_to(foo, function(x)
        return x <= 0
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    bar = M.keep_while_to(foo, function(x)
        return x >= 0
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, orig_list))

    -- Top Idx

    bar = M.keep_while_to(foo, function(x)
        return x <= 10
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, orig_list))

    bar = M.keep_while_to(foo, function(x)
        return x >= 10
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, { 10 }))

    -- Over Idx

    bar = M.keep_while_to(foo, function(x)
        return x <= 11
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, orig_list))

    bar = M.keep_while_to(foo, function(x)
        return x >= 11
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    ---------------------
    -- Rm New List Fwd --
    ---------------------

    -- Middle idx

    bar = M.rm_while_to(foo, function(x)
        return x <= 3
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, { 4, 5, 6, 7, 8, 9, 10 }))

    bar = M.rm_while_to(foo, function(x)
        return x >= 3
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, orig_list))

    -- Bottom Idx

    bar = M.rm_while_to(foo, function(x)
        return x <= 1
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, { 2, 3, 4, 5, 6, 7, 8, 9, 10 }))

    bar = M.rm_while_to(foo, function(x)
        return x >= 1
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    -- Zero Idx

    bar = M.rm_while_to(foo, function(x)
        return x <= 0
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, orig_list))

    bar = M.rm_while_to(foo, function(x)
        return x >= 0
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    -- Top Idx

    bar = M.rm_while_to(foo, function(x)
        return x <= 10
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    bar = M.rm_while_to(foo, function(x)
        return x >= 10
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }))

    -- Over Idx

    bar = M.rm_while_to(foo, function(x)
        return x <= 11
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    bar = M.rm_while_to(foo, function(x)
        return x >= 11
    end)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, orig_list))

    ---------------------
    -- Rm New List Rev --
    ---------------------

    -- Middle idx

    bar = M.rm_while_to(foo, function(x)
        return x <= 3
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, orig_list))

    bar = M.rm_while_to(foo, function(x)
        return x >= 3
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, { 1, 2 }))

    -- Bottom Idx

    bar = M.rm_while_to(foo, function(x)
        return x <= 1
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, orig_list))

    bar = M.rm_while_to(foo, function(x)
        return x >= 1
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    -- Zero Idx

    bar = M.rm_while_to(foo, function(x)
        return x <= 0
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, orig_list))

    bar = M.rm_while_to(foo, function(x)
        return x >= 0
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    -- Top Idx

    bar = M.rm_while_to(foo, function(x)
        return x <= 10
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    bar = M.rm_while_to(foo, function(x)
        return x >= 10
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, { 1, 2, 3, 4, 5, 6, 7, 8, 9 }))

    -- Over Idx

    bar = M.rm_while_to(foo, function(x)
        return x <= 11
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, {}))

    bar = M.rm_while_to(foo, function(x)
        return x >= 11
    end, true)
    assert(vim.deep_equal(foo, orig_list))
    assert(vim.deep_equal(bar, orig_list))
end
