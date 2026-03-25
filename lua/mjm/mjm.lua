local api = vim.api

_G.mjm = {}

mjm.v = {}
mjm.v.fmt_lhs = "<leader>o"

-- Problem:
-- - I have ftplugin files that modify options. I want them to be able to do so safely
-- - vim.opt and set are non-specific about scope (global/local only)
-- - Options are in a liminal state: (https://github.com/neovim/neovim/issues/20107)
-- Solution:
-- - Hack together interfaces for cleanly working with options
--
-- LOW: Handle list and dict options. Dict would be helpful because it would get rid of hackiness
-- around how I have listchars built for Go. List is less relevant because I only append to them
-- in initial setup. Everything in ftplugins is an overwrite.
mjm.opt = {}

---@param opt string
---@param flags_in string[]
---@param scope vim.api.keyset.option
function mjm.opt.flag_add(opt, flags_in, scope)
    local old = api.nvim_get_option_value(opt, scope) ---@type string
    local new = { old } ---@type string[]
    for _, flag in ipairs(flags_in) do
        if string.find(old, flag, 1, true) == nil then
            new[#new + 1] = flag
        end
    end

    api.nvim_set_option_value(opt, table.concat(new, ""), scope)
end

---@param opt string
---@param flags_out string[]
---@param scope vim.api.keyset.option
function mjm.opt.flag_rm(opt, flags_out, scope)
    local val = api.nvim_get_option_value(opt, scope) ---@type string
    for _, flag in ipairs(flags_out) do
        val = string.gsub(val, flag, "")
    end

    api.nvim_set_option_value(opt, val, scope)
end
-- MID: Is it better to split val into a table and filter on flags_out?

mjm.win = {}

---@param cur_pos { [1]: integer, [2]: integer }
---@param opts? { win?: integer }
---@return nil
function mjm.win.protected_set_cursor(cur_pos, opts)
    opts = opts or {}
    local win = opts.win or api.nvim_get_current_win()
    local buf = api.nvim_win_get_buf(win)

    local row = math.max(cur_pos[1], 1)
    local line_count = api.nvim_buf_line_count(buf)
    row = math.min(row, line_count)

    local line = api.nvim_buf_get_lines(buf, row - 1, row, false)[1]
    local len_line_0 = math.max(#line - 1, 0)
    local col = math.min(cur_pos[2], len_line_0)

    api.nvim_win_set_cursor(win, { row, col })
end
