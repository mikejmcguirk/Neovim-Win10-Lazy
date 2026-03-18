local api = vim.api

local M = {}

local function check_ft()
    return api.nvim_get_option_value("filetype", { buf = 0 }) == "lua"
end
-- TODO: Delete once proper comment string checking is added.

---@param cur_buf boolean
function M.fzf_lua_grep(cur_buf)
    if not check_ft() then
        return
    end

    local fzf_lua = require("fzf-lua")
    if not fzf_lua then
        return
    end

    local grep = cur_buf and fzf_lua.grep_curbuf or fzf_lua.grep
    grep({ regex = "^\\s*-- MARK:" })
end
-- TODO: This regex assumes rg. How do we know what grep fzf-lua is actually using?

---@param cur_buf boolean
function M.rancher_grep(cur_buf)
    if not check_ft() then
        return
    end

    local r_grep = require("qf-rancher.grep")
    if not r_grep then
        return
    end

    local src_win = cur_buf == true and 0 or nil
    local locs = require("qf-rancher.lib.grep-locs")
    local loc = cur_buf and locs.get_cur_buf or locs.get_cwd
    r_grep.grep(src_win, " ", {}, {
        case = "sensitive",
        locations = loc,
        name = "MARK",
        pattern = "^\\s*-- MARK:",
        regex = true,
    }, {})
end
-- TODO: Issues when using this:
-- - I don't know why I am inputting a what table.
--   - I assume this is for customizable qflist behavior, like plugging in a qftext function, but
--   it's not clear if there are any mandatory fields, or if any of the fields I inputted will be
--   overridden by the function
--   - We should be able to safely assume that an empty or nil table input does not create an
--   issue.
-- - Unless I want to use a custom function, I should be able to input a string arg for locations.
-- - Fzflua's method of having pattern and regex being separate inputs is superior. IMO regex
-- should override pattern.
-- - The "QfrSystemOpts" link in the Grep documentation is incorrect.
-- - You should be able to input a string arg for the System sort arg, unless you want to use a
-- custom function.
-- - In sync, "syncrhonously" is a typo.
-- - Except for timeout, none of the SystemOpts list their default behavior.
-- - None of the defaults are listed for grep opts either.
-- - It should not be necessary to pass empty tables for either grep opts or system opts
-- - Same thing with every other plugin, I should be able to do require("qf-rancher").grep()
-- - While the issue with results not being found was due to an error in creating the <Plug> maps,
-- the lack of troubleshooting tools was not helpful. I don't think the full cmd should print to
-- the cmdline each time, but you should be able to look at it in messages. I would have been able
-- to see that I was running the wrong grep. Note that the :messages printout should be truncated
-- if the list of locations gets overly long.
-- TODO: This regex assumes rg is being used. rancher uses a config var to determine what grepprg
-- it uses, but that doesn't solve the issue then of adjusting the regex. I can ship a grep string
-- I suppose for each grepprg rancher supports.

return M

-- TODO: For cwd grep, is it possible to search each file based on its individual commentstring? Or
-- are you stuck with the commentstring of the current file?
-- - This prompts the creation of a plugin-internal search tool that is commentstring aware
-- -
-- TODO: Like the other modules, these function need to be super-sets of the various annotation
-- and comment string combinations we can see. An issue is that the various types of comment
-- strings out there + the various types of regex out there create a combinatorially complex
-- problem.
