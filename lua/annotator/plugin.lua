local api = vim.api

api.nvim_set_keymap("n", "<Plug>(annotator-add-mark)", "", {
    noremap = true,
    callback = function()
        require("annotator").add_annotation()
    end,
})

api.nvim_set_keymap("n", "<Plug>(annotator-add-borders)", "", {
    noremap = true,
    callback = function()
        require("annotator").add_borders()
    end,
})

local annotator = require("annotator")

api.nvim_set_keymap("n", "<Plug>(annotator-jump-rev)", "", {
    noremap = true,
    callback = function()
        annotator.jump(-1)
    end,
})

api.nvim_set_keymap("n", "<Plug>(annotator-jump-fwd)", "", {
    noremap = true,
    callback = function()
        annotator.jump(1)
    end,
})

local config = annotator.config()

if config.create_plug_integrations then
    api.nvim_set_keymap("n", "<Plug>(annotator-fzf-lua-grep-curbuf)", "", {
        noremap = true,
        callback = function()
            annotator.fzf_lua_grep(true)
        end,
    })

    api.nvim_set_keymap("n", "<Plug>(annotator-fzf-lua-grep-cwd)", "", {
        noremap = true,
        callback = function()
            annotator.fzf_lua_grep(false)
        end,
    })

    api.nvim_set_keymap("n", "<Plug>(annotator-rancher-grep-curbuf)", "", {
        noremap = true,
        callback = function()
            annotator.rancher_grep(true)
        end,
    })

    api.nvim_set_keymap("n", "<Plug>(annotator-rancher-grep-cwd)", "", {
        noremap = true,
        callback = function()
            annotator.rancher_grep(false)
        end,
    })
end

if config.set_default_maps == true then
    api.nvim_set_keymap("n", "[k", "<Plug>(annotator-jump-rev)", { noremap = true })
    api.nvim_set_keymap("n", "]k", "<Plug>(annotator-jump-fwd)", { noremap = true })
end

-- Concepts:
-- - Strict vs. relaxed search. Strict search cares about exact semantics and tolerates false
-- negatives. Relaxed search only cares if the annotation is in a comment, and tolerates false
-- positives
-- - The user should be able to input annotations without the colon, and the plugin should add the
-- colon programmatically.
--
-----------
-- TODO: --
-----------
--
-- Beforehand:
--
-- - Finish farsight, then fix rancher and lampshade.
-- - Research folke's todo-comments.
--   - Handle early because I want to design around the complete scope of the problem.
--   - What other similar plugins are out there?
-- Study https://github.com/spywhere/vscode-mark-jump
--
-- Strict detection (loaded buffer):
-- - Match against cms
-- - We assume, for any MARK heading, that the entirety of it must be on one line. For languages
-- like Lua, this doesn't really matter, since we can grab the start, but for markdown this
-- means we need to see the start and end of the commentstring on one line
-- - cms must be the first non-whitespace character on the line
-- - Markdown example:
--   - ^{start of 'com' with space}{user annotation}{colon}{greedy .*}{end of 'com' with space}
-- - Mistakes to avoid:
--   - For new annotations, carelessly adding spaces to the end and putting the cursor there.
--     - Additional spaces + cursor positioning need to account for anything after %s
--   - Any grep string cleanup needs to be before and after %s
--
-- Relaxed Detection (loaded buffer):
-- - Is some cur_pos in some buffer a comment?
--   - Would probably use something like folke's todo-comments function, particularly because of
--   the fallback syntax checking.
--
-- Text Tools
-- - Create the following addtion methods:
--   - Blank line
--   - Non-blank line, append
--   - Non-blank line, push contents down
-- - Border char setup:
--   - Check the first chars of the comment string. If they are all the same, with the next
--   character(s) being a space or %s, the char can be used
-- - For any text tools, use logic similar to vim._comment to get the nested treesitter cms
--
-- Built-in Search:
-- - Jump Primitives:
--   - Inputs:
--     - Cursor
--     - Dir
--     - Allow all folds or allow no folds
--       - The logic being, a user either wants to jump to whatever the next annotation is, or
--       folds should be folds.
--   - Must wrapscan
--   - Cannot use backwards search
--     - Does have to address though, what if you are in a long buffer and the next result is
--     right above the cursor? Must we wait for the search to traverse all the way from the top?
--   - Has to address results almost but not quite on the cursor
--
-- - Buffer Primitives:
--   - Always include all folded results
--
-- - Both Primities:
--   - Ideally, the results would be the same as external integrations, because the same logic
--   can be used to operate on them
--   - Logic to narrow down results to a list of filenames, eliminating redundant ftdetect
--
-- - Jump logic:
--   - Skip function
--     - Use logic similar to vim._comment to get the nested treesitter cms
--     - Track count. Note that count should only be decremented on valid results
--
-- Integration primitives:
-- - Which grep is being used?
--   - Fzf-lua
--   - Rancher
--   - Snacks
--   - Telescope
-- - Based on grepprg, determine the proper search syntax
-- - Ways to reduce incoming files:
--   - Ignore hidden files by default
--   - Respect gitignore by default
--   - If in a git directory, perhaps only look at tracked files by default
-- - Checking integration result validity
--   - Narrow down the results to a list of filenames
--   - Loaded buffer: Use methods above
--   - Unloaded buffer:
--     - Relaxed: I'm not sure ther's more that can be done, due to languages with multi-line
--     comment syntax
--       - Probably put a pin on trying to parse "comments". But even then, we have to be willing
--       to let in false negatives
--     - Strict:
--       - vim.filetype.match()
--       - vim.filetype.get_option()
--       - Check semantics of result against commentstring
--       - Profile this.
--
--
-- Plug Mappings:
-- - Jump navigation between the various TODO annotations
-- - Built-in search
--   - Cur buf
--   - All bufs where bufhidden == false and
--
--
-- TODO: What level of precision is actually needed for searching and navigation?
-- - At minimum, we should never be searching or navigating to results that are not in comments
--   - This is in-line with todo-comments
--   - This would indeed require treesitter parsing, again, as todo-comments does
-- - "Start only" should be an optional flag.
--   - This is necessary for non-MARK cases, you might have something like:
--     local foo = bar + 1 -- TODO: Find source of off-by-one error
--   - Anything MARK related would be advertised as start-only because they are meant to be
--   file headings
--   - Some kind of defaults would then be provided for common items like "TODO", which would
--   not be start-only
--     - You could do what todo-comments does and wrap them all up into one thing.
--   - Batch the results in stages. First isolate them by file, then by extension
--   - How do you get commentstring for buffers that are not open?
-- TODO: Need a name for this plugin/convention. In VSCode these are called marks, which does not
-- fit with Neovim. Folke uses todo-comments. But I'm not sure that fits with [k]k navigation.
-- On the other hand, "comment-navigator" is not a terrible plugin name.
-- - Handle early because it's less to rename.
-- TODO: Comment parsing.
-- - Use 'commentstring' because it's simple and universal.
-- - The parsing functions should be in their own file since most modules need it.
-- - We will need the embedded language logic from vim._comment
-- - Any parsing needs to work within the "owned" format specifier
-- TODO: Finders:
-- - Current buf
--   - Use search()
--   - Like jumps, this needs to check for annotations, then check the commentstring based on the
--   individual embedded language.
--   - Default: Send results to location list
--   - Integrations:
--     - Picker:
--       - Send results to picker
--     - Rancher:
--       - Use its tools to send to qflist
-- - All open bufs
--   - Use search()
--   - Narrow to currently open bufs (ftdetected) (bufhidden = false and buftype == "")
--   - Like jumps, this needs to check for annotations, then check the commentstring based on the
--   individual embedded language.
--   - Default: Send results to qflist
--   - Integrations:
--     - Picker:
--       - Send results to picker
--     - Rancher:
--       - Use its tools to send to qflist
-- - CWD integrations:
--   - Fzf-Lua
--     - Grep first for the annotation
--     - For any un-opened files, ft-detect them
--       - fn_postprocess
--     - Filter the results to make sure they match the comment syntax
--     - Send the results to fzf-Lua for further refinement
--   - Rancher
--     - Grep for the annotation
--     - For any un-opened files, ft-detect them
--     - Filter the results
--       - I think rancher's system module would need an "on_results" callback that would be used
--       for custom results filtering
--         - This might also help solve the weird issue of the result type for helpgrep being
--         set to "\1" arbitrarily
--     - Use rancher to send to the qflist
-- - Do not use vimgrep, because its list output cannot be controlled
-- - Because most users will have a picker integration, do not map the finders by default, so that
-- users can map the finders based on how they namespace their integration
-- - The CWD ftdetect is a serious area of perf concern (discussed above)
