require("mjm")

-- MID: Why is matchparen working? I have it set to 1 in set. Do you need to do it through lazy?
-- MID: Would prefer that the jumplist not inherit bufs from other sessions. I'm not necessarily
-- against just starting it fresh each time
-- MID: The new float statusline would be useful to show win info/buf info

-- LOW: Cannot use vim._with because it complains about unsetting global variables when using lz
-- Either do a PR (but unsure how _with_c works) or write a Lua version
-- LOW: How to do document exports. pandoc? 2html? Is there a plugin?
-- LOW: Commentary on surcor style resetting. https://github.com/neovim/neovim/pull/36261
-- And also discussion: https://github.com/neovim/neovim/discussions/32540
-- It looks like tmux is the remaining case where it doesn't work. Lots of different things
-- colliding here. Unsure what the action items are

-- PR: Fix the missing fields annotations in certain keysets (nvim_cmd being the worst)
-- PR: https://github.com/neovim/neovim/issues/36081 - I might be able to get this

----------------------
-- DOTFILE STALKING --
----------------------

-- https://github.com/folke/dot/tree/master/nvim
-- https://github.com/stevearc/dotfiles/tree/master/.config/nvim
-- https://github.com/b0o/nvim-conf/tree/main
-- https://nvim-mini.org/MiniMax/configs/nvim-0.11/

---------------
-- RESOURCES --
---------------

-- https://github.com/tjdevries/lazy-require.nvim
-- https://neo451.github.io/blog/posts/in-process-lsp-guide/
-- - vim.pack buffers do this as well

-----------------
-- OTHER NOTES --
-----------------

-- export NVIM_APPNAME=some-other-thing will make the config .config/some-other-thing

-- BASELINE setup:
-- - Use <esc> or <C-c> as your main mode switching key (influences multi-cursor)

-- For getting filename roots, once you deal with all the necessary bookkeeping, pure Lua is
-- slower than just using vim.fn.fnamemodify(path, ":r")

-- TEST_FILE=test/functional/autocmd/win_scrolled_resized_spec.lua make functionaltest

-- https://antonk52.github.io/webdevandstuff/post/2025-11-30-diy-easymotion.html
