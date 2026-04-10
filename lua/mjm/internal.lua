require("farsight.plugin")

local api = vim.api
local set = vim.keymap.set

api.nvim_set_hl(0, "FarsightJump", { reverse = true })
api.nvim_set_hl(0, "FarsightJumpAhead", { underdouble = true })
api.nvim_set_hl(0, "FarsightJumpTarget", { reverse = true })

api.nvim_set_hl(0, "FarsightCsearch1st", { reverse = true })
api.nvim_set_hl(0, "FarsightCsearch2nd", { undercurl = true })
api.nvim_set_hl(0, "FarsightCsearch3rd", { underdouble = true })

-- set({ "n", "x", "o" }, "/", function()
--     return require("farsight.search").search(1)
-- end, { expr = true })
--
-- set({ "n", "x", "o" }, "?", function()
--     return require("farsight.search").search(-1)
-- end, { expr = true })

-- set("n", "s", function()
--     require("farsight.live").live_jump()
-- end)

api.nvim_set_var("farsight_csearch_all_tokens", true)

--------------

require("annotator.plugin")
set("n", "<leader>-k", "<Plug>(annotator-add-mark)")
set("n", "<leader>-K", "<Plug>(annotator-add-borders)")
set("n", "<leader>fnk", "<Plug>(annotator-fzf-lua-grep-curbuf)")
set("n", "<leader>fnK", "<Plug>(annotator-fzf-lua-grep-cwd)")
set("n", "<leader>qgk", "<Plug>(annotator-rancher-grep-cwd)")
set("n", "<leader>lgk", "<Plug>(annotator-rancher-grep-curbuf)")

--------------

set({ "n", "x" }, "y", function()
    return require("specops").yank()
end, { expr = true })

set({ "n", "x" }, "Y", function()
    return require("specops").yank() .. "$"
end, { expr = true })

set({ "n", "x" }, "<M-y>", function()
    return '"+' .. require("specops").yank()
end, { expr = true })

set({ "n", "x" }, "<M-Y>", function()
    return '"+' .. require("specops").yank() .. "$"
end, { expr = true })

set("x", "p", "P")
set("x", "P", "p")
set("n", "<M-p>", '"+p')
set("n", "<M-P>", '"+P')
set("x", "<M-p>", '"+P')
set("x", "<M-P>", '"+p')

set("n", "[p", '<Cmd>exe "iput! " . v:register<CR>')
set("n", "]p", '<Cmd>exe "iput "  . v:register<CR>')
set("n", "[<M-p>", '<Cmd>exe "iput! " . "+"<CR>')
set("n", "]<M-p>", '<Cmd>exe "iput "  . "+"<CR>')

set({ "n", "x" }, "<M-d>", '"_d')
set({ "n", "x" }, "<M-D>", '"_D')
set({ "n", "x" }, "<M-c>", '"_c')
set({ "n", "x" }, "<M-C>", '"_C')

local function word_by_word_md_leak_test()
    -- Base text (plain English + a few markdown elements to stress the TS markdown parser)
    local base_text = [[
lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore magna aliqua
ut enim ad minim veniam quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat
duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur
excepteur sint occaecat cupidatat non proident sunt in culpa qui officia deserunt mollit anim id est laborum

**bold text** *italic text* `code` [link](https://example.com) ## heading list item - bullet point
  ]]

    -- Split into words (keeps punctuation attached so it looks more natural)
    local base_words = vim.split(base_text, "%s+", { trimempty = true })

    -- Build a list of ~1200 words by cycling the base list (you can change 1200 to whatever you want)
    local word_list = {}
    for i = 1, 1200 do
        local word = base_words[(i % #base_words) + 1]
        table.insert(word_list, word .. " ")
    end

    local i = 1

    local function insert_one_word()
        if i > #word_list then
            print(
                "✅ Word-by-word insert test finished ("
                    .. #word_list
                    .. " words). Monitor memory now!"
            )
            return
        end

        local bufnr = 0 -- current buffer
        local row, col = unpack(vim.api.nvim_win_get_cursor(0))

        -- Insert the next word at the current cursor position (exactly like typing)
        vim.api.nvim_buf_set_text(bufnr, row - 1, col, row - 1, col, { word_list[i] })

        -- Move cursor forward so the next insert happens after the just-added word
        vim.api.nvim_win_set_cursor(0, { row, col + #word_list[i] })

        i = i + 1

        -- Schedule the next word. This is the key part:
        -- It yields back to the event loop so Treesitter can re-parse the buffer
        -- between each individual word insertion.
        vim.schedule(insert_one_word)
    end

    -- Start the recursion
    print("🚀 Starting word-by-word insert test (1200 words)…")
    insert_one_word()
end

-- Keymap: <leader><leader> in normal mode
vim.keymap.set("n", "<leader><leader>", word_by_word_md_leak_test, {
    desc = "Diagnose Neovim/Treesitter memory leak in Markdown (inserts ~1200 words one-by-one with vim.schedule)",
    noremap = true,
    silent = true,
})
