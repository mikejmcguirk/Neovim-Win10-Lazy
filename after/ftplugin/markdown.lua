local gf = require("mjm.global_funcs")

gf.adjust_tab_width(2)
vim.opt_local.wrap = true

vim.opt_local.spell = true

vim.opt_local.colorcolumn = ""
vim.opt_local.sidescrolloff = 12

-- Formatting handled by prettier through conform

local root_start = gf.get_buf_directory(vim.fn.bufnr(""))

vim.lsp.start({
    name = "marksman",
    cmd = { "marksman", "server" },
    root_dir = gf.find_proj_root({ ".marksman.toml" }, root_start, root_start),
    single_file_support = true,
    capabilities = Lsp_Capabilities,
})
