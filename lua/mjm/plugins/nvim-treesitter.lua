------------------------
-- Treesitter Parsers --
------------------------

local languages = {
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
    "tmux",
    "typescript",
}

require("nvim-treesitter").install(languages)

local ft_extensions = { "sh" }
local fts = vim.tbl_extend("force", languages, ft_extensions)

vim.api.nvim_create_autocmd({ "FileType" }, {
    group = vim.api.nvim_create_augroup("ts-start", { clear = true }),
    pattern = fts,
    callback = function(ev)
        vim.treesitter.start()
        local indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        vim.api.nvim_buf_set_var(ev.buf, "indentexpr", indentexpr)
    end,
})

vim.api.nvim_create_autocmd("VimEnter", {
    group = vim.api.nvim_create_augroup("run-tsupdate", { clear = true }),
    pattern = "*",
    callback = function()
        vim.schedule(function()
            -- PR: Don't need the "all parsers up-to-date" message
            vim.cmd("TSUpdate")
        end)
    end,
})

-----------------------------
-- Treesitter Text Objects --
-----------------------------

--- @return Range4
local function get_vrange4()
    local cur = vim.fn.getpos(".")
    local fin = vim.fn.getpos("v")
    local mode = vim.fn.mode()

    local region = vim.fn.getregionpos(cur, fin, { type = mode, exclusive = false })
    return { region[1][1][2], region[1][1][3], region[#region][2][2], region[#region][2][3] }
end

local function get_cursor_orientation()
    local vrange4 = get_vrange4()
    vrange4[2] = math.max(vrange4[2] - 1, 0)
    vrange4[4] = math.max(vrange4[4] - 1, 0)

    local row, col = unpack(vim.api.nvim_win_get_cursor(0))

    local at_start = row == vrange4[1] and col == vrange4[2]
    local at_fin = row == vrange4[3] and col == vrange4[4]
    if at_start and not at_fin then
        return "start"
    elseif (not at_start) and at_fin then
        return "fin"
    else
        return "center"
    end
end

Map("x", "<leader><leader>", get_cursor_orientation)

local objects = "nvim-treesitter-textobjects"

local function setup_objects()
    require(objects).setup({
        select = {
            lookahead = true,
            selection_modes = {
                ["@call.inner"] = "v",
                ["@call.outer"] = "v",
                ["@comment.inner"] = "v",
                ["@comment.outer"] = "v",
                ["@conditional.inner"] = "v",
                ["@conditional.outer"] = "v",
                ["@function.inner"] = "v",
                ["@function.outer"] = "v",
                ["@parameter.inner"] = "v",
                ["@parameter.outer"] = "v",
                ["@preproc.inner"] = "v",
                ["@preproc.outer"] = "v",
            },
            include_surrounding_whitespace = false,
        },
        move = {
            set_jumps = false,
        },
    })

    vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("object-maps", { clear = true }),
        callback = function(ev)
            if not vim.tbl_contains(languages, ev.match) then
                return
            end

            ----------------
            -- Selections --
            ----------------

            local select = require(objects .. ".select")
            local select_maps = {
                -- Spot checking, the only language I've seen that has a @comment.inner is Python
                { "is", "@assignment.rhs" },
                { "as", "@assignment.outer" },
                { "iS", "@assignment.lhs" },
                { "aS", "@assignment.inner" },
                { "iM", "@call.inner" },
                { "aM", "@call.outer" },
                { "i/", "@comment.inner" },
                { "a/", "@comment.outer" },
                { "io", "@conditional.inner" },
                { "ao", "@conditional.outer" },
                { "im", "@function.inner" },
                { "am", "@function.outer" },
                { "i,", "@parameter.inner" },
                { "a,", "@parameter.outer" },
                { "i#", "@preproc.inner" },
                { "a#", "@preproc.outer" },
            }

            for _, m in pairs(select_maps) do
                Map({ "x", "o" }, m[1], function()
                    select.select_textobject(m[2], "textobjects")
                end, { buffer = ev.buf })
            end

            -----------
            -- Gotos --
            -----------

            local move = require(objects .. ".move")
            local move_maps = {
                { "[g", "]g", "@assignment.outer" }, --- Mismatch
                { "[G", "]G", "@assignment.inner" }, --- Mismatch
                { "[M", "]M", "@call.outer" },
                { "[/", "]/", "@comment.outer" },
                { "[o", "]o", "@conditional.outer" },
                { "[m", "]m", "@function.outer" },
                { "[,", "],", "@parameter.inner" },
                { "[#", "]#", "@preproc.outer" },
            }

            for _, m in pairs(move_maps) do
                Map("n", m[1], function()
                    move.goto_previous_start(m[3], "textobjects")
                end, { buffer = ev.buf })

                Map("n", m[2], function()
                    move.goto_next_start(m[3], "textobjects")
                end, { buffer = ev.buf })

                Map("o", m[1], function()
                    move.goto_previous_start(m[3], "textobjects")
                end, { buffer = ev.buf })

                Map("o", m[2], function()
                    move.goto_next_end(m[3], "textobjects")
                end, { buffer = ev.buf })

                -- FUTURE: In theory, the better way to handle this is to have some sort of
                -- lookahead rather than potentially performing a triple-move if you cross over
                -- the origin of the visual selection

                Map({ "x" }, m[1], function()
                    local orientation = get_cursor_orientation()

                    if orientation == "end" then
                        move.goto_previous_end(m[3], "textobjects")

                        local new_orientation = get_cursor_orientation()
                        if new_orientation == "start" then
                            move.goto_next_end(m[3], "textobjects")
                            move.goto_previous_start(m[3], "textobjects")
                        end
                    else
                        move.goto_previous_start(m[3], "textobjects")
                    end
                end, { buffer = ev.buf })

                Map("x", m[2], function()
                    local orientation = get_cursor_orientation()

                    if orientation == "start" then
                        move.goto_next_start(m[3], "textobjects")

                        local new_orientation = get_cursor_orientation()
                        if new_orientation == "end" then
                            move.goto_previous_start(m[3], "textobjects")
                            move.goto_next_end(m[3], "textobjects")
                        end
                    else
                        move.goto_next_end(m[3], "textobjects")
                    end
                end, { buffer = ev.buf })
            end

            -----------
            -- Swaps --
            -----------

            local swap = require(objects .. ".swap")
            local swap_maps = {
                { "(g", ")g", "@assignment.outer" }, --- Mismatch
                { "(G", ")G", "@assignment.inner" }, --- Mismatch
                { "(M", ")M", "@call.outer" },
                { "(/", ")/", "@comment.outer" },
                { "(/", ")/", "@conditional.outer" },
                { "(m", ")m", "@function.outer" },
                { "(,", "),", "@parameter.inner" },
                { "(#", ")#", "@preproc.inner" },
            }

            for _, m in pairs(swap_maps) do
                Map("n", m[1], function()
                    swap.swap_previous(m[3], "textobjects")
                end, { buffer = ev.buf })

                Map("n", m[2], function()
                    swap.swap_next(m[3], "textobjects")
                end, { buffer = ev.buf })
            end
        end,
    })
end

vim.api.nvim_create_autocmd({ "BufNewFile", "BufReadPre" }, {
    group = vim.api.nvim_create_augroup("setup-objects", { clear = true }),
    once = true,
    callback = function()
        setup_objects()
        vim.api.nvim_del_augroup_by_name("setup-objects")
    end,
})
