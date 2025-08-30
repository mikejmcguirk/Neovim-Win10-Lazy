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
                ["@parameter.inner"] = "v",
                ["@parameter.outer"] = "v",
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

            -- TODO: # For PreProcs. See builtin #[ #]
            -- TODO: Check if the function queries also grab methods
            -- TODO: Want to put in the swap mappings. Look at stuff like substitute,
            -- mini.operators, and their related plugins to see what their conventions are
            -- Also look at Abolish and its coerce mappings. Kinda thinking cx, maybe sx. But
            -- want to get into a broader pattern here that other things can slot into
            -- TODO: Use a table and a loop to do mappings. Don't just use one to do all options
            -- because we might have a situation like GitSigns where the letters don't match.
            -- Maybe use a separate table for mapping conventions

            -- FUTURE: It would be useful to scan the textobjects.scm file for a relevant query
            -- and map a vim.notify message if none is found

            ----------------
            -- Selections --
            ----------------

            local select = require(objects .. ".select")

            -- Just spot checking, the only language I've seen that has a @comment.inner is Python
            vim.keymap.set({ "x", "o" }, "i/", function()
                select.select_textobject("@comment.inner", "textobjects")
            end, { buffer = ev.buf })

            vim.keymap.set({ "x", "o" }, "a/", function()
                select.select_textobject("@comment.outer", "textobjects")
            end, { buffer = ev.buf })

            vim.keymap.set({ "x", "o" }, "im", function()
                select.select_textobject("@function.inner", "textobjects")
            end, { buffer = ev.buf })

            vim.keymap.set({ "x", "o" }, "am", function()
                select.select_textobject("@function.outer", "textobjects")
            end, { buffer = ev.buf })

            vim.keymap.set({ "x", "o" }, "i,", function()
                select.select_textobject("@parameter.inner", "textobjects")
            end, { buffer = ev.buf })

            vim.keymap.set({ "x", "o" }, "a,", function()
                select.select_textobject("@parameter.outer", "textobjects")
            end, { buffer = ev.buf })

            vim.keymap.set({ "x", "o" }, "i#", function()
                select.select_textobject("@preproc.inner", "textobjects")
            end, { buffer = ev.buf })

            vim.keymap.set({ "x", "o" }, "a#", function()
                select.select_textobject("@preproc.outer", "textobjects")
            end, { buffer = ev.buf })

            -----------
            -- Gotos --
            -----------

            local move = require(objects .. ".move")

            -- Overwrite vim default
            vim.keymap.set({ "n", "x", "o" }, "[/", function()
                move.goto_previous_start("@comment.outer", "textobjects")
            end, { buffer = ev.buf })

            vim.keymap.set({ "n", "x", "o" }, "]/", function()
                move.goto_next_start("@comment.outer", "textobjects")
            end, { buffer = ev.buf })

            -- Overwrite vim default
            vim.keymap.set({ "n", "x", "o" }, "[m", function()
                move.goto_previous_start("@function.outer", "textobjects")
            end, { buffer = ev.buf })

            vim.keymap.set({ "n", "x", "o" }, "]m", function()
                move.goto_next_start("@function.outer", "textobjects")
            end, { buffer = ev.buf })

            vim.keymap.set({ "n", "x", "o" }, "[,", function()
                move.goto_previous_start("@parameter.inner", "textobjects")
            end, { buffer = ev.buf })

            vim.keymap.set({ "n", "x", "o" }, "],", function()
                move.goto_next_start("@parameter.inner", "textobjects")
            end, { buffer = ev.buf })

            -- Overwrite vim default
            vim.keymap.set({ "n", "x", "o" }, "[#", function()
                move.goto_previous_start("@preproc.outer", "textobjects")
            end, { buffer = ev.buf })

            vim.keymap.set({ "n", "x", "o" }, "]#", function()
                move.goto_next_start("@preproc.outer", "textobjects")
            end, { buffer = ev.buf })
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
