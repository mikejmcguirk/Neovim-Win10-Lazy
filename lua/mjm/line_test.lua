local api = vim.api
local uv = vim.uv

---@param pos string
---@param win? integer
---@return integer
local function lua_fn_line(pos, win)
    win = win or 0
    local buf = win == 0 and 0 or api.nvim_win_get_buf(win)

    local b1 = string.byte(pos, 1)
    if b1 == 46 then -- '.'
        return api.nvim_win_get_cursor(win)[1]
    elseif b1 == 36 then -- '$'
        return api.nvim_buf_line_count(buf)
    elseif b1 == 39 then -- '
        return api.nvim_buf_get_mark(buf, string.sub(pos, 2))[1]
    elseif b1 == 34 then -- "
        return api.nvim_buf_get_mark(buf, '"')[1]
    end

    error("Unsupported position for lua_fn_line_byte: " .. vim.inspect(pos))
end

-- mark 'a

local function iter_lua_fn()
    local positions = { ".", "$", "'a", ".", "$", "'b", ".", "$", '"' }
    local iterations = 2000000
    local total_calls = iterations * #positions

    local total_vim = 0
    local total_lua = 0

    local cur_win = api.nvim_get_current_win()

    for _ = 1, iterations do
        for _, pos in ipairs(positions) do
            local start = uv.hrtime()
            local _ = vim.call("line", pos, cur_win)
            local stop = uv.hrtime()
            total_vim = total_vim + (stop - start)
        end
    end

    for _ = 1, iterations do
        for _, pos in ipairs(positions) do
            local start = uv.hrtime()
            local _ = lua_fn_line(pos, cur_win)
            local stop = uv.hrtime()
            total_lua = total_lua + (stop - start)
        end
    end

    local vim_ns = total_vim / total_calls
    local byte_ns = total_lua / total_calls

    -- mark 'b

    print("\n=== line() Performance Comparison ===")
    print(string.format("Positions     : %s", table.concat(positions, ", ")))
    print(string.format("Total calls   : %d", total_calls))
    print(
        "────────────────────────────────────"
    )
    print(
        string.format("vim.call      : %7.2f µs total  (%6.0f ns/call)", total_vim / 1000, vim_ns)
    )
    print(
        string.format("lua_fn      : %7.2f µs total  (%6.0f ns/call)", total_lua / 1000, byte_ns)
    )
    print(
        "────────────────────────────────────"
    )
    print(string.format("lua_fn vs vim : %.2fx faster", vim_ns / byte_ns))
    print(
        "────────────────────────────────────"
    )
end

vim.keymap.set("n", "<leader><leader>", iter_lua_fn)
