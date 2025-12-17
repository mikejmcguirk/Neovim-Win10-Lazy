---@param annotation string
---@return nil
local function add_annotation(annotation)
    local row, col = unpack(vim.api.nvim_win_get_cursor(0)) ---@type integer, integer
    local row_0 = row - 1 ---@type integer
    local col_1 = col + 1 ---@type integer
    local line = vim.api.nvim_get_current_line()

    -- Right after three dashes
    if col_1 >= 3 and line:sub(col_1 - 2, col_1) == "---" then
        vim.api.nvim_buf_set_text(0, row_0, col_1, row_0, col_1, { annotation .. " " })
    elseif line:match("^%s*$") then -- All whitespace
        local padding = string.rep(" ", require("mjm.utils").get_indent(row) or 0) ---@type string
        local padded_annotation = padding .. "---" .. annotation .. " "
        vim.api.nvim_buf_set_text(0, row_0, 0, row_0, #line, { padded_annotation })
    elseif line:match("%s$") then -- Non-whitespace with trailing whitespace
        vim.api.nvim_buf_set_text(0, row_0, #line, row_0, #line, { "---" .. annotation .. " " })
    else -- Non-whitespace without trailing whitespace
        local new_text = " ---" .. annotation .. " " ---@type string
        vim.api.nvim_buf_set_text(0, row_0, #line, row_0, #line, { new_text })
    end

    -- Going into insert kills dot repeating anyway, so use the cmd instead of scheduling feedkeys
    vim.api.nvim_cmd({ cmd = "startinsert", bang = true }, {})
end

vim.keymap.set("n", "<leader>-a", function()
    add_annotation("[[@as")
end, { buffer = 0 })

vim.keymap.set("n", "<leader>-c", function()
    add_annotation("@class")
end, { buffer = 0 })

vim.keymap.set("n", "<leader>-d", function()
    add_annotation("@diagnostic")
end, { buffer = 0 })

vim.keymap.set("n", "<leader>-e", function()
    add_annotation("@export")
end, { buffer = 0 })

vim.keymap.set("n", "<leader>-f", function()
    add_annotation("@field")
end, { buffer = 0 })

vim.keymap.set("n", "<leader>-i", function()
    add_annotation("@private")
end, { buffer = 0 })

vim.keymap.set("n", "<leader>-l", function()
    add_annotation("@alias")
end, { buffer = 0 })

vim.keymap.set("n", "<leader>-m", function()
    add_annotation("@mod")
end, { buffer = 0 })

vim.keymap.set("n", "<leader>-p", function()
    add_annotation("@param")
end, { buffer = 0 })

vim.keymap.set("n", "<leader>-r", function()
    add_annotation("@return")
end, { buffer = 0 })

vim.keymap.set("n", "<leader>-t", function()
    add_annotation("@type")
end, { buffer = 0 })

vim.keymap.set("n", "<leader>--", function()
    add_annotation("")
end, { buffer = 0 })

mjm.lsp.start(vim.lsp.config["lua_ls"], { bufnr = 0 })
