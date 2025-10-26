require("mjm")

-- LOW: Do not love the diffing solutions out there. Perhaps one can be fashioned out of DiffTool
-- LOW: How does Fugitive do line wrap in commit buffers?
-- LOW: Look for table.inserts and see if they can be replaced with t[#t + 1]

-- PR: Fix the missing fields annotations in certain keysets (nvim_cmd being the worst)
-- PR: https://github.com/neovim/neovim/issues/36081 - I might be able to get this

----------------------
-- DOTFILE STALKING --
----------------------

-- https://github.com/folke/dot/tree/master/nvim
-- https://github.com/stevearc/dotfiles/tree/master/.config/nvim
-- https://github.com/b0o/nvim-conf/tree/main

---------------
-- RESOURCES --
---------------

-- https://github.com/tjdevries/lazy-require.nvim

-----------------
-- OTHER NOTES --
-----------------

-- export NVIM_APPNAME=some-other-thing will make the config .config/some-other-thing
