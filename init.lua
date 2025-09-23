require("mjm")

--- TODO: For any variable access that I have, use the vim.g/vim.b accessors. The code is fairly
--- efficient and they are robust against missing values

--- PR: Fix the missing fields error in nvim_cmd mods tables

-- https://github.com/folke/dot/tree/master/nvim
-- https://github.com/stevearc/dotfiles/tree/master/.config/nvim
-- https://github.com/b0o/nvim-conf/tree/main
--
-- export NVIM_APPNAME=some-other-thing
-- will then look in .config/some-other-thing for config
