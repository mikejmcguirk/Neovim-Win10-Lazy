------------------------
-- Treesitter Parsers --
------------------------

vim.cmd.packadd({ vim.fn.escape("nvim-treesitter", " "), bang = true, magic = { file = false } })

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

vim.api.nvim_create_autocmd({ "FileType" }, {
    group = vim.api.nvim_create_augroup("ts-start", { clear = true }),
    pattern = "*",
    callback = function(ev)
        if vim.tbl_contains(languages, ev.match) then
            vim.treesitter.start()
        end

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

local objects = "nvim-treesitter-textobjects"

local function setup_objects()
    require(objects).setup({
        select = {
            lookahead = true,
            selection_modes = {
                ["@comment.inner"] = "v",
                ["@comment.outer"] = "v",
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
                { "i/", "@comment.inner" },
                { "a/", "@comment.outer" },
                { "im", "@function.inner" },
                { "am", "@function.outer" },
                { "i,", "@parameter.inner" },
                { "a,", "@parameter.outer" },
                { "i#", "@preproc.inner" },
                { "a#", "@preproc.outer" },
            }

            for _, m in pairs(select_maps) do
                vim.keymap.set({ "x", "o" }, m[1], function()
                    select.select_textobject(m[2], "textobjects")
                end, { buffer = ev.buf })
            end

            -----------
            -- Gotos --
            -----------

            local move = require(objects .. ".move")
            local move_maps = {
                { "[/", "]/", "@comment.outer" },
                { "[m", "]m", "@function.outer" },
                { "[,", "],", "@parameter.inner" },
                { "[#", "]#", "@preproc.outer" },
            }

            for _, m in pairs(move_maps) do
                vim.keymap.set("n", m[1], function()
                    move.goto_previous_start(m[3], "textobjects")
                end, { buffer = ev.buf })

                vim.keymap.set("n", m[2], function()
                    move.goto_next_start(m[3], "textobjects")
                end, { buffer = ev.buf })
            end

            -----------
            -- Swaps --
            -----------

            local swap = require(objects .. ".swap")
            local swap_maps = {
                { "[/", "]/", "@comment.outer" },
                { "[m", "]m", "@function.outer" },
                { "[,", "],", "@parameter.inner" },
                { "[#", "]#", "@preproc.inner" },
            }

            for _, m in pairs(swap_maps) do
                vim.keymap.set("n", "cx" .. m[1], function()
                    swap.swap_previous(m[3], "textobjects")
                end, { buffer = ev.buf })

                vim.keymap.set("n", "cx" .. m[2], function()
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
        require("mjm.pack").post_load(objects)
        setup_objects()
    end,
})
