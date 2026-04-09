local api = vim.api
local set = vim.keymap.set
local set_opt = api.nvim_set_option_value

set_opt("nu", true, { scope = "global" })
set_opt("rnu", true, { scope = "global" })

local group = api.nvim_create_augroup("mjm-md-test", {})

api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "Markdown",
    callback = function(ev)
        local buf = ev.buf

        local local_scope = { scope = "local" }
        set_opt("culopt", "screenline, number", local_scope)
        set_opt("siso", 12, local_scope)
        set_opt("spell", true, local_scope)
        set_opt("wrap", true, local_scope)

        local buf_0 = { buf = buf }
        set("i", ",", ",<C-g>u", buf_0)
        set("i", ".", ".<C-g>u", buf_0)
        set("i", ":", ":<C-g>u", buf_0)
        set("i", "-", "-<C-g>u", buf_0)
        set("i", "?", "?<C-g>u", buf_0)
        set("i", "!", "!<C-g>u", buf_0)
    end,
})

-- If the options don't nuke it, try text tools next. Wondering if they cause a memory leak
