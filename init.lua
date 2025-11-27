require("mjm")

-- MID: Would prefer that the jumplist not inherit bufs from other sessions. I'm not necessarily
-- against just starting it fresh each time
-- MID: The new float statusline would be useful to show win info/buf info

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

-----------------
-- OTHER NOTES --
-----------------

-- export NVIM_APPNAME=some-other-thing will make the config .config/some-other-thing

-- BASELINE setup:
-- - Use <esc> or <C-c> as your main mode switching key (influences multi-cursor)

-- For getting filename roots, once you deal with all the necessary bookkeeping, pure Lua is
-- slower than just using vim.fn.fnamemodify(path, ":r")

-- TEST_FILE=test/functional/autocmd/win_scrolled_resized_spec.lua make functionaltest
