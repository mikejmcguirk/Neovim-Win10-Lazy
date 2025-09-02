-- FUTURE:
-- - LSP Buf Rename Integration
-- - Make + open qf
-- - 2html or equivalent
-- - pandoc export

--- @return integer|nil, string|nil
local function get_cur_buf()
    local buf = vim.api.nvim_get_current_buf()
    if not vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_echo({ { "Buf is invalid", "DiagnosticWarn" } }, true, { err = true })
        return nil, nil
    end

    local bufname = vim.api.nvim_buf_get_name(buf)
    if bufname == "" then
        vim.api.nvim_echo({ { "Buf has no path", "" } }, true, { err = true })
        return nil, nil
    end

    return buf, bufname
end

--- @param path string
--- @return boolean
local function is_git_tracked(path)
    if not vim.g.gitsigns_head then
        return false
    end

    local cmd = { "git", "ls-files", "--error-unmatch", "--", path }
    local output = vim.system(cmd):wait()
    if output.code == 0 then
        return true
    else
        return false
    end
end

-- MAYBE: Is the cmdline history/feedback worth how cumbersome this is?

--- @return string
local function move_buf()
    local buf, bufname = get_cur_buf()
    if (not buf) or not bufname then
        return ""
    end --- @type integer|nil, string|nil

    local full_path = vim.fn.fnamemodify(bufname, ":p")
    local is_tracked = is_git_tracked(full_path)

    if is_tracked then
        return ":GMove! " .. full_path
    end

    local prompt = "Enter new path for " .. full_path .. " : "
    local new_name = require("mjm.utils").get_input(prompt)
    if new_name == "" then
        return ""
    end

    local new_path = vim.fn.fnamemodify(new_name, ":p")
    local escape_path = vim.fn.fnameescape(new_path)

    local mv_cmd = ':lua vim.fn.rename("' .. full_path .. '", "' .. escape_path .. '") '
    local saveas = "vim.cmd('keepalt saveas! " .. escape_path .. "')"
    return mv_cmd .. saveas
end

-- MAYBE: Is the cmdline history/feedback worth how cumbersome this is?

--- @return string
local function del_cur_buf()
    local buf, bufname = get_cur_buf()
    if (not buf) or not bufname then
        return ""
    end

    if vim.api.nvim_get_option_value("modified", { buf = buf }) then
        local cur_win = vim.api.nvim_get_current_win()
        local tabs = vim.api.nvim_list_tabpages()

        for _, t in ipairs(tabs) do
            local wins = vim.api.nvim_tabpage_list_wins(t)
            for _, w in ipairs(wins) do
                if vim.api.nvim_win_get_buf(w) == buf and w ~= cur_win then
                    local msg = "Buf modified and open elsewhere. Aborting"
                    vim.api.nvim_echo({ { msg, "" } }, true, { err = true })
                    return ""
                end
            end
        end
    end

    local full_path = vim.fn.fnamemodify(bufname, ":p")
    local is_tracked = is_git_tracked(full_path)

    if is_tracked then
        return ":GDelete!"
    else
        return ':lua vim.fn.delete("'
            .. full_path
            .. '") vim.api.nvim_buf_delete('
            .. buf
            .. ", { force = true })"
    end
end

local function chmod_x()
    local buf, bufname = get_cur_buf()
    if (not buf) or not bufname then
        return
    end

    local full_path = vim.fn.fnamemodify(bufname, ":p")
    local chmod = vim.system({ "chmod", "+x", full_path }):wait()
    if chmod.code == 0 then
        return
    end

    local err = chmod.stderr or ("Cannot chmod " .. full_path)
    vim.api.nvim_echo({ { err, "ErrorMsg" } }, true, { err = true })
end

local function chmod_X()
    local buf, bufname = get_cur_buf()
    if (not buf) or not bufname then
        return
    end

    local full_path = vim.fn.fnamemodify(bufname, ":p")
    local chmod = vim.system({ "chmod", "-x", full_path }):wait()
    if chmod.code == 0 then
        return
    end

    local err = chmod.stderr or ("Cannot chmod " .. full_path)
    vim.api.nvim_echo({ { err, "ErrorMsg" } }, true, { err = true })
end

Map("n", "g\\bd", del_cur_buf, { expr = true })
Map("n", "g\\bm", move_buf, { expr = true })

Map("n", "g\\cx", chmod_x)
Map("n", "g\\cX", chmod_X)
