-- Variables and vim keymaps are set first so, if there is an issue with Lazy, they are
-- still usable
-- Additionally, an E21 can occur if trying to run these after Lazy
require("mjm.set")
require("mjm.keymap")

require("mjm.lazy")

-- Set here so, if there is an issue with Lazy, autocmds don't interfere with troubleshooting
require("mjm.autocmd")
