local gf = require("mjm.global_funcs")

-- Formatting by prettier through conform

local root_start = gf.get_buf_directory(vim.fn.bufnr())
vim.lsp.start(gf.setup_tsserver(root_start))
