local api = vim.api
local ut = Mjm_Defer_Require("mjm.utils")

local langs = {
    -- Mandatory
    "c",
    "lua",
    "vim",
    "vimdoc",
    "query",
    "markdown_inline",
    "markdown",
    -- Optional
    "c_sharp",
    "bash",
    "css",
    "diff",
    "javascript",
    "json",
    "gitattributes",
    "gitcommit",
    "gitignore",
    "git_rebase",
    "go",
    "html",
    "perl",
    "python",
    "rust",
    "sql",
    -- "tmux", -- Errors on things that are correct
    "typescript",
}

require("nvim-treesitter").install(langs)
langs[#langs + 1] = "sh"
api.nvim_create_autocmd({ "FileType" }, {
    group = api.nvim_create_augroup("ts-start", {}),
    pattern = langs,
    callback = function(ev)
        vim.treesitter.start(ev.buf)
        local indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        api.nvim_set_option_value("indentexpr", indentexpr, { buf = ev.buf })
    end,
})

-- PR: The "parsers up to date" message is annoying
api.nvim_create_autocmd("UIEnter", {
    group = api.nvim_create_augroup("run-tsupdate", {}),
    pattern = "*",
    callback = function()
        vim.schedule(function()
            api.nvim_cmd({ cmd = "TSUpdate" }, {})
        end)
    end,
})

---@return "start"|"center"|"fin"
local function get_vpos()
    local vrange4 = ut.get_vrange4() ---@type Range4
    vrange4[2] = math.max(vrange4[2] - 1, 0)
    vrange4[4] = math.max(vrange4[4] - 1, 0)

    local row, col = unpack(api.nvim_win_get_cursor(0))
    local at_start = row == vrange4[1] and col == vrange4[2]
    local at_fin = row == vrange4[3] and col == vrange4[4]

    if at_start and not at_fin then return "start" end
    if (not at_start) and at_fin then return "fin" end
    return "center"
end

local objects = "nvim-treesitter-textobjects"
local function map_objects(ev)
    local select_maps = {
        { "is", "@assignment.rhs" },
        { "as", "@assignment.outer" },
        { "iS", "@assignment.lhs" },
        { "aS", "@assignment.inner" },
        { "if", "@call.inner" }, -- From minimal init
        { "af", "@call.outer" },
        { "i/", "@comment.inner" }, -- :h [/
        { "a/", "@comment.outer" },
        { "ii", "@conditional.inner" },
        { "ai", "@conditional.outer" },
        { "im", "@function.inner" }, -- :h [m
        { "am", "@function.outer" },
        { "io", "@loop.inner" }, -- From minimal init
        { "ao", "@loop.outer" },
        { "i,", "@parameter.inner" },
        { "a,", "@parameter.outer" },
        { "i.", "@return.inner" },
        { "a.", "@return.outer" },
        -- Custom object
        { "i#", "@preproc.inner" }, -- :h [#
        { "a#", "@preproc.outer" },
    }

    local select = require(objects .. ".select")
    for _, m in pairs(select_maps) do
        vim.keymap.set({ "x", "o" }, m[1], function()
            select.select_textobject(m[2], "textobjects")
        end, { buffer = ev.buf })
    end

    local move_maps = {
        { "[s", "]s", "@assignment.outer" },
        { "[f", "]f", "@call.outer" },
        { "[/", "]/", "@comment.outer" },
        { "[i", "]i", "@conditional.outer" },
        { "[m", "]m", "@function.outer" },
        { "[o", "]o", "@loop.outer" },
        { "[,", "],", "@parameter.inner" }, -- To perform edits inside strings
        { "[.", "].", "@return.outer" },
        -- Custom objects
        { "[#", "]#", "@preproc.outer" },
        { '["', ']"', "@string.inner" }, -- To perform edits inside
    }

    local move = require(objects .. ".move")
    for _, m in pairs(move_maps) do
        vim.keymap.set({ "n", "o" }, m[1], function()
            move.goto_previous_start(m[3], "textobjects")
        end, { buffer = ev.buf })

        vim.keymap.set("n", m[2], function()
            move.goto_next_start(m[3], "textobjects")
        end, { buffer = ev.buf })

        vim.keymap.set("o", m[2], function()
            move.goto_next_end(m[3], "textobjects")
        end, { buffer = ev.buf })

        vim.keymap.set({ "x" }, m[1], function()
            if get_vpos() ~= "fin" then
                move.goto_previous_start(m[3], "textobjects")
                return
            end

            move.goto_previous_end(m[3], "textobjects")
            if get_vpos() == "start" then move.goto_previous_start(m[3], "textobjects") end
        end, { buffer = ev.buf })

        vim.keymap.set("x", m[2], function()
            if get_vpos() ~= "start" then
                move.goto_next_end(m[3], "textobjects")
                return
            end

            move.goto_next_start(m[3], "textobjects")
            if get_vpos() == "fin" then move.goto_next_end(m[3], "textobjects") end
        end, { buffer = ev.buf })
    end

    local swap_maps = {
        { "(s", ")s", "@assignment.outer" },
        { "(f", ")f", "@call.outer" },
        { "(/", ")/", "@comment.outer" },
        { "(i", ")i", "@conditional.outer" },
        { "(m", ")m", "@function.outer" },
        { "(o", ")o", "@loop.outer" },
        { "(,", "),", "@parameter.inner" }, -- Outer can break commas if swapped at end
        { "(.", ").", "@return.outer" },
        -- Custom objects
        { "(#", ")#", "@preproc.outer" },
        { '("', ')"', "@string.outer" },
    }

    vim.keymap.set("n", "(", "<nop>", { buffer = ev.buf })
    vim.keymap.set("n", ")", "<nop>", { buffer = ev.buf })
    local swap = require(objects .. ".swap")
    for _, m in pairs(swap_maps) do
        vim.keymap.set("n", m[1], function()
            swap.swap_previous(m[3], "textobjects")
        end, { buffer = ev.buf })

        vim.keymap.set("n", m[2], function()
            swap.swap_next(m[3], "textobjects")
        end, { buffer = ev.buf })
    end
end

local function setup_objects()
    require(objects).setup({
        select = { lookahead = true, include_surrounding_whitespace = false },
        move = { set_jumps = false },
    })

    api.nvim_create_autocmd("FileType", {
        group = api.nvim_create_augroup("objects-map", {}),
        pattern = langs,
        callback = map_objects,
    })
end

local objects_setup = api.nvim_create_augroup("objects-setup", {})
api.nvim_create_autocmd({ "BufNewFile", "BufReadPre" }, {
    group = objects_setup,
    once = true,
    callback = function()
        setup_objects()
        api.nvim_del_augroup_by_id(objects_setup)
    end,
})
