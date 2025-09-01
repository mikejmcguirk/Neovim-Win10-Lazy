local rnu_control = vim.api.nvim_create_augroup("rnu_control", { clear = true })

---@param event string|string[]
---@param pattern string
---@param value boolean
---@return nil
local set_rnu = function(event, pattern, value)
    vim.api.nvim_create_autocmd(event, {
        group = rnu_control,
        pattern = pattern,
        callback = function(ev)
            local win = vim.api.nvim_get_current_win()
            vim.api.nvim_set_option_value("rnu", value, { win = win })
            if ev.event == "CmdlineEnter" then
                if not vim.tbl_contains({ "@", "-" }, vim.v.event.cmdtype) then
                    vim.cmd("redraw")
                end
            end
        end,
    })
end

-- Note: Need BufLeave/BufEnter for this to work when going into help. Seems like the autocmds run
-- before the buf is loaded, and rnu can't be set on Win Enter since there's no buffer
set_rnu({ "WinLeave", "CmdlineEnter", "BufLeave" }, "*", false)
set_rnu({ "WinEnter", "CmdlineLeave", "BufEnter" }, "*", true)

vim.opt.ts = 4
vim.opt.sts = 4
vim.opt.sw = 4
vim.opt.et = true
vim.opt.sr = true

vim.opt.ru = false

vim.opt.so = Scrolloff_Val
vim.opt.matchpairs:append("<:>")
vim.opt.cpoptions:append("W")
vim.opt.cpoptions:append("Z")

vim.opt.si = true
vim.opt.bs = "indent,eol,nostop"
vim.opt.sel = "old"

vim.opt.shortmess:append("W")
vim.opt.shortmess:append("s")
vim.opt.shortmess:append("r")

vim.opt.ic = true
vim.opt.scs = true
-- Don't want screen shifting while entering search/subsitute patterns
vim.opt.is = false

vim.opt.list = true
vim.opt.listchars = { tab = "<–>", extends = "»", precedes = "«", nbsp = "␣", trail = "⣿" }
-- vim.opt.listchars = { eol = "↲", tab = "<–>", extends = "»", precedes = "«", nbsp = "␣" }

local list_control = vim.api.nvim_create_augroup("list-control", { clear = true })
vim.api.nvim_create_autocmd("InsertEnter", {
    group = list_control,
    callback = function()
        vim.api.nvim_set_option_value("list", false, { win = vim.api.nvim_get_current_win() })
    end,
})

vim.api.nvim_create_autocmd("InsertLeave", {
    group = list_control,
    callback = function()
        vim.api.nvim_set_option_value("list", true, { win = vim.api.nvim_get_current_win() })
    end,
})

-- Buffer local option
-- See help fo-table
vim.api.nvim_create_autocmd({ "FileType" }, {
    group = vim.api.nvim_create_augroup("format-control", { clear = true }),
    pattern = "*",
    callback = function(ev)
        vim.opt.formatoptions:remove("o")

        if not ev.match == "markdown" then
            -- "r" in Markdown treats lines like "- some text" as comments and indents them
            vim.opt.formatoptions:append("r")
        end
    end,
})
