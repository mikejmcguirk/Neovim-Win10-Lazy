return {
    "bullets-vim/bullets.vim",
    -- enabled = false,
    init = function()
        local api = vim.api

        local fts = { "gitcommit", "markdown", "text" }
        api.nvim_set_var("bullets_enabled_file_types", fts)
        api.nvim_set_var("bullets_max_alpha_characters", 1)
        api.nvim_set_var("bullets_set_mappings", 0)

        api.nvim_create_autocmd("FileType", {
            group = api.nvim_create_augroup("mjm-map-bullets", {}),
            pattern = fts,
            callback = function(ev)
                local set = vim.keymap.set
                local buf = ev.buf
                local opts = { buf = buf }

                set("i", "<cr>", "<Plug>(bullets-newline)", opts)

                set("n", "<<", "<Plug>(bullets-promote)", opts)
                set("n", ">>", "<Plug>(bullets-demote)", opts)
                set("i", I_Dedent, "<Plug>(bullets-promote)", opts)
                set("i", "<C-t>", "<Plug>(bullets-demote)", opts)
                -- NOTE: Do not map promote/demote in x mode because it does not properly gv into
                -- the old visual selection

                set("n", "<C-n>", "<Plug>(bullets-renumber)", opts)
                set("v", "<C-n>", "<Plug>(bullets-renumber)", opts)
            end,
        })
    end,
}

-- LOW: When I hit enter in a markdown file, I can see the line numbers flicker. It is doing
-- some kind of goofy nonsense under the hood
-- LOW: This would be a good Lua re-write. Current limitations:
-- - Only creates a new bullet if at the end of the line. So, cannot bring contents down into a
-- new bullet
-- - Promote/demote cannot take a non-bulleted line and add it to the list above. You have to
-- go up, make the new bullet, then join with J
-- - As noted above, promote/demote in visual mode does not properly handle the old visual
-- selection
-- MAYBE: For maps, could let default logic happen then demap, but this is simpler
-- MAYBE: Trying to use default levels. Can edit/hack if it contradicts my old notes
