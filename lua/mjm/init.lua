-- An E21 can occur if trying to run these after Lazy
require("mjm.env_variables")
require("mjm.set")
require("mjm.keymap")

require("mjm.lazy")

-- Set here so, if there is an issue with Lazy, autocmds don't interfere with troubleshooting
require("mjm.autocmd")
