-- Settings first, then Lazy, or else an E21 occurs
-- Even on a fresh install, plugin dependent settings will be picked up
require("mjm.vim_set")
require("mjm.plugin_set")
require("mjm.vim_keymaps")

require("mjm.lazy")

require("mjm.plugin_keymaps")
require("mjm.autocmd")
