local api = vim.api
local set = vim.keymap.set

---@type string[]
local langs = {
    -- Update built-ins
    "c",
    "lua",
    "vim",
    "vimdoc",
    "query",
    "markdown_inline",
    "markdown",
    -- Others
    "bash",
    "c_sharp",
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
    "typst",
}

local fts = vim.deepcopy(langs, true) ---@type string[]
fts[#fts + 1] = "sh"

---@return integer
local function get_vpos()
    local vregionpos4 = require("mjm.utils").get_vregionpos4() ---@type Range4|nil
    if not vregionpos4 then
        return 0
    end

    vregionpos4[2] = math.max(vregionpos4[2] - 1, 0)
    vregionpos4[4] = math.max(vregionpos4[4] - 1, 0)

    local row, col = unpack(api.nvim_win_get_cursor(0)) ---@type integer, integer
    local start = row == vregionpos4[1] and col == vregionpos4[2] and -1 or 0 ---@type integer
    local fin = row == vregionpos4[3] and col == vregionpos4[4] and 1 or 0 ---@type integer

    local sum = start + fin ---@type integer
    return sum
end

-- LOW: PR: It would be useful if the Text Object maps set a prior context mark if they moved far
-- enough.

---@param ev vim.api.keyset.create_autocmd.callback_args
---@return nil
local function map_objects(ev)
    ---@type {[1]: string, [2]:string }[]
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

    local select = require("nvim-treesitter-textobjects.select")
    for _, m in pairs(select_maps) do
        set({ "x", "o" }, m[1], function()
            select.select_textobject(m[2], "textobjects")
        end, { buffer = ev.buf })
    end

    ---@type {[1]:string, [2]:string, [3]:string }[]
    local move_maps = {
        { "[s", "]s", "@assignment.outer" },
        { "[f", "]f", "@call.outer" },
        { "[/", "]/", "@comment.outer" },
        { "[i", "]i", "@conditional.outer" },
        { "[m", "]m", "@function.outer" },
        { "[o", "]o", "@loop.outer" },
        { "[,", "],", "@parameter.inner" },
        { "[.", "].", "@return.outer" },
        -- Custom objects
        { "[#", "]#", "@preproc.outer" },
        { '["', ']"', "@string.inner" },
    }

    local move = require("nvim-treesitter-textobjects.move")
    for _, m in pairs(move_maps) do
        set({ "n", "o" }, m[1], function()
            move.goto_previous_start(m[3], "textobjects")
        end, { buffer = ev.buf })

        set("n", m[2], function()
            move.goto_next_start(m[3], "textobjects")
        end, { buffer = ev.buf })

        set("o", m[2], function()
            move.goto_next_end(m[3], "textobjects")
        end, { buffer = ev.buf })

        set({ "x" }, m[1], function()
            local first_vpos = get_vpos() ---@type integer
            if first_vpos < 1 then
                move.goto_previous_start(m[3], "textobjects")
                return
            end

            local cur_start = api.nvim_win_get_cursor(0)
            move.goto_previous_end(m[3], "textobjects")
            local next_vpos = get_vpos()
            if next_vpos == -1 then
                api.nvim_win_set_cursor(0, cur_start)
                move.goto_previous_start(m[3], "textobjects")
            end
        end, { buffer = ev.buf })

        set("x", m[2], function()
            local start_vpos = get_vpos() ---@type integer
            if start_vpos > -1 then
                move.goto_next_end(m[3], "textobjects")
                return
            end

            local cur_start = api.nvim_win_get_cursor(0)
            move.goto_next_start(m[3], "textobjects")
            local fin_vpos = get_vpos()
            if fin_vpos == 1 then
                api.nvim_win_set_cursor(0, cur_start)
                move.goto_next_end(m[3], "textobjects")
            end
        end, { buffer = ev.buf })
    end

    ---@type { [1]:string, [2]:string, [3]:string }[]
    local swap_maps = {
        { "(s", ")s", "@assignment.rhs" },
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

    set("n", "(", "<nop>", { buffer = ev.buf })
    set("n", ")", "<nop>", { buffer = ev.buf })
    local swap = require("nvim-treesitter-textobjects.swap")
    for _, m in pairs(swap_maps) do
        set("n", m[1], function()
            swap.swap_previous(m[3], "textobjects")
        end, { buffer = ev.buf })

        set("n", m[2], function()
            swap.swap_next(m[3], "textobjects")
        end, { buffer = ev.buf })
    end
end

---@param ev vim.api.keyset.create_autocmd.callback_args
---@return nil
local function map_climber(ev)
    local sel_prev = { buffer = ev.buf, desc = "Select previous node" }
    set({ "n", "x", "o" }, "[e", "<Plug>(treeclimber-select-previous)", sel_prev)
    local sel_next = { buffer = ev.buf, desc = "Select the next node" }
    set({ "n", "x" }, "]e", "<Plug>(treeclimber-select-next)", sel_next)
    local sel_forward_end = { buffer = ev.buf, desc = "Select forward and move to node end" }
    set({ "o" }, "]e", "<Plug>(treeclimber-select-forward-end)", sel_forward_end)

    local s_back = { buffer = ev.buf, desc = "Select first sibling" }
    set({ "n", "x", "o" }, "[E", "<Plug>(treeclimber-select-siblings-backward)", s_back)
    local s_front = { buffer = ev.buf, desc = "Select last sibling" }
    set({ "n", "x", "o" }, "]E", "<Plug>(treeclimber-select-siblings-forward)", s_front)

    local grow_back = { buffer = ev.buf, desc = "Grow selection backward" }
    set({ "n", "x", "o" }, "[<C-e>", "<Plug>(treeclimber-select-grow-backward)", grow_back)
    local grow_forward = { buffer = ev.buf, desc = "Grow selection forward" }
    set({ "n", "x", "o" }, "]<C-e>", "<Plug>(treeclimber-select-grow-forward)", grow_forward)

    -- PR: I would be good to have shrink backward and shrink forward maps. Would put them on
    -- alt
    -- PR: Would be useful to have a "sibling fill" map. Would, for example, select all
    -- neightboring function parameters. Would put on iE

    local sel_cur = { buffer = ev.buf, desc = "Select child node" }
    set({ "x", "o" }, "ie", "<Plug>(treeclimber-select-shrink)", sel_cur)
    local sel_exp = { buffer = ev.buf, desc = "Select parent node (around)" }
    set({ "x", "o" }, "ae", "<Plug>(treeclimber-select-expand)", sel_exp)
end

return {
    {
        "nvim-treesitter/nvim-treesitter",
        -- LOW: Unsure why this still has to be set manually even though it's the default
        branch = "main",
        build = ":TSUpdate",
        config = function()
            require("nvim-treesitter").install(langs)

            api.nvim_create_autocmd({ "FileType" }, {
                group = api.nvim_create_augroup("mjm-ts-start", {}),
                pattern = fts,
                callback = function(ev)
                    vim.treesitter.start(ev.buf)
                    local expr = "v:lua.require'nvim-treesitter'.indentexpr()" ---@type string
                    api.nvim_set_option_value("indentexpr", expr, { buf = ev.buf })
                end,
            })
        end,
    },
    {
        "nvim-treesitter/nvim-treesitter-textobjects",
        branch = "main",
        init = function()
            require("nvim-treesitter-textobjects").setup({
                select = {
                    lookahead = true,
                    include_surrounding_whitespace = false,
                },
                move = { set_jumps = false },
            })

            api.nvim_create_autocmd("FileType", {
                group = api.nvim_create_augroup("mjm-ts-objects-map", {}),
                pattern = fts,
                callback = map_objects,
            })
        end,
    },
    {
        "nvim-treesitter/nvim-treesitter-context",
        init = function()
            require("treesitter-context").setup({
                enable = true,
                separator = "─",
            })

            -- MAYBE: Disable rnu in context windows?
            set("n", "<leader>tc", "<cmd>TSContext toggle<cr>")
        end,
    },
    {
        -- MID: Plugin enter errors when trying to grow selection in markdown. Unsure if this is
        -- a treeclimber or Neovim issue
        "Dkendal/nvim-treeclimber",
        init = function()
            api.nvim_set_var("treeclimber", { highlight = false })
            api.nvim_create_autocmd("FileType", {
                group = api.nvim_create_augroup("mjm-map-climber", {}),
                pattern = fts,
                callback = map_climber,
            })
        end,
    },
}

-- TODO: PR: Inconsistency between text objects, the upcoming built-in incremental selection, and
-- tree-climber - When you do move in text objects, it grows the selection, but the baseline
-- selection in the incremental selection plugins actually moves the selection. Crosses wires in
-- muscle memory.
