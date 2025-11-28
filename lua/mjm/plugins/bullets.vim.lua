return {
    "bullets-vim/bullets.vim",
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

                set("i", "<cr>", "<Plug>(bullets-newline)", { buffer = ev.buf })

                set("n", "<<", "<Plug>(bullets-promote)", { buffer = ev.buf })
                set("n", ">>", "<Plug>(bullets-demote)", { buffer = ev.buf })
                set("i", I_Dedent, "<Plug>(bullets-promote)", { buffer = ev.buf })
                set("i", "<C-t>", "<Plug>(bullets-demote)", { buffer = ev.buf })
                set("v", "<", "<Plug>(bullets-promote)", { buffer = ev.buf })
                set("v", ">", "<Plug>(bullets-demote)", { buffer = ev.buf })

                set("n", "<C-n>", "<Plug>(bullets-renumber)", { buffer = ev.buf })
                set("v", "<C-n>", "<Plug>(bullets-renumber)", { buffer = ev.buf })
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
-- MAYBE: For maps, could let default logic happen then demap, but this is simpler
-- MAYBE: Trying to use default levels. Can edit/hack if it contradicts my old notes
