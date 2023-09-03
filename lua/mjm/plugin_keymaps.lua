local opts = { noremap = true, silent = true }
local loudOpts = { noremap = true, silent = false }

local keymap = vim.keymap.set

----------
-- Lazy --
----------

local lazy = require("lazy")

keymap("n", "<leader>zc", lazy.check, loudOpts)
keymap("n", "<leader>zx", lazy.clean, loudOpts)
keymap("n", "<leader>zd", lazy.debug, loudOpts)
keymap("n", "<leader>ze", lazy.help, loudOpts)
keymap("n", "<leader>zh", lazy.home, loudOpts)
keymap("n", "<leader>zi", lazy.install, loudOpts)
keymap("n", "<leader>zl", lazy.log, loudOpts)
keymap("n", "<leader>zp", lazy.profile, loudOpts)
keymap("n", "<leader>zs", lazy.sync, loudOpts)
keymap("n", "<leader>zu", lazy.update, loudOpts)

---------------
-- Telescope --
---------------

require('telescope').setup {
    defaults = {
        mappings = {
            n = {
                ["<C-h>"] = "which_key",
                ['<c-d>'] = require('telescope.actions').delete_buffer,
                ['<up>'] = false,
                ['<down>'] = false,
                ['<left>'] = false,
                ['<right>'] = false,
                ['<PageUp>'] = false,
                ['<PageDown>'] = false,
                ['<Home>'] = false,
                ['<End>'] = false,
            },
            i = {
                ["<C-h>"] = "which_key",
                ['<c-d>'] = require('telescope.actions').delete_buffer,
                ['<up>'] = false,
                ['<down>'] = false,
                ['<left>'] = false,
                ['<right>'] = false,
                ['<PageUp>'] = false,
                ['<PageDown>'] = false,
                ['<Home>'] = false,
                ['<End>'] = false,
            }
        }
    }
}

require('telescope').load_extension('fzf')
require('telescope').load_extension('harpoon')

local builtin = require("telescope.builtin")

keymap('n', '<leader>tb', function()
    builtin.buffers({ show_all_buffers = true })
end)

keymap('n', '<leader>to', builtin.command_history, opts)
keymap('n', '<leader>td', builtin.diagnostics, opts)

keymap('n', '<leader>tf', function()
    builtin.find_files({hidden = true})
end, opts)

keymap('n', '<leader>tg', builtin.git_files, opts)

keymap('n', '<leader>ts', function()
    builtin.grep_string({ search = vim.fn.input("Grep > ") })
end)

keymap('n', '<leader>ta', "<cmd>Telescope harpoon marks<cr>", opts)
keymap('n', '<leader>th', builtin.help_tags, opts)

keymap('n', '<leader>tl', function()
    builtin.grep_string({
        prompt_title = "Help",
        search = "",
        search_dirs = vim.api.nvim_get_runtime_file("doc/*.txt", "all"),
        only_sort_text = true,
    })
end)

keymap('n', '<leader>tg', builtin.highlights, opts)
keymap('n', '<leader>te', builtin.live_grep, opts)
keymap('n', '<leader>tw', builtin.lsp_workspace_symbols, opts)
keymap('n', '<leader>ti', builtin.registers, opts)
keymap('n', '<leader>tr', builtin.resume, opts)

-------------
-- Harpoon --
-------------

local marked = require("harpoon.mark")
local fromUI = require("harpoon.ui")

keymap("n", "<leader>ad", function()
    marked.add_file()
    -- After switching from Packer to Lazy, the Harpoon tabline does not automatically update
    -- when a new mark is added. I think this is related to Lazy's lazy execution causing
    -- Harpoon's emit_changed() function to either not run properly or run on a delay
    -- The below cmd is a hack to deal with this issue. By running an empty command, it forces
    -- the tabline to redraw
    vim.cmd([[normal! :<esc>]])
end)

keymap("n", "<leader>ae", fromUI.toggle_quick_menu, opts)

local function get_or_create_buffer(filename)
    local buf_exists = vim.fn.bufexists(filename) ~= 0

    if buf_exists then
        return vim.fn.bufnr(filename)
    end

    return vim.fn.bufadd(filename)
end


local function windows_nav_file(id)
    require("harpoon.dev").log.trace("nav_file(): Navigating to", id)

    local idx = marked.get_index_of(id)

    if not marked.valid_index(idx) then
        require("harpoon.dev").log.debug("nav_file(): No mark exists for id", id)
        return
    end

    local mark = marked.get_marked_file(idx)
    -- The repo's version of nav_file performs a normalize function on the filename that
    -- converts saved hooks to Unix path formatting. On Windows, because the marks are saved in
    -- Windows file format, the mark in the function does not match the saved mark and therefore
    -- is not recognized by the tabline. This implementation removes the normalization
    local buf_id = get_or_create_buffer(mark.filename)
    local set_row = not vim.api.nvim_buf_is_loaded(buf_id)
    local old_bufnr = vim.api.nvim_get_current_buf()

    vim.api.nvim_set_current_buf(buf_id)
    vim.api.nvim_buf_set_option(buf_id, "buflisted", true)

    if set_row and mark.row and mark.col then
        vim.cmd(string.format(":call cursor(%d, %d)", mark.row, mark.col))

        require("harpoon.dev").log.debug(
            string.format(
                "nav_file(): Setting cursor to row: %d, col: %d",
                mark.row,
                mark.col
            )
        )
    end

    local old_bufinfo = vim.fn.getbufinfo(old_bufnr)

    if type(old_bufinfo) == "table" and #old_bufinfo >= 1 then
        old_bufinfo = old_bufinfo[1]
        local no_name = old_bufinfo.name == ""
        local one_line = old_bufinfo.linecount == 1
        local unchanged = old_bufinfo.changed == 0

        if no_name and one_line and unchanged then
            vim.api.nvim_buf_delete(old_bufnr, {})
        end
    end
end

for i = 1, 9 do
  keymap("n", string.format("<leader>%s", i), function()
      windows_nav_file(i) end, opts)
end

---------
-- LSP --
---------

--I think lus_ls wants if this is not a global because
--we're working with the global "vim" outside the scope of a function
DiagOpts = { noremap = true }

keymap("n", "[d", vim.diagnostic.goto_prev, DiagOpts)
keymap("n", "]d", vim.diagnostic.goto_next, DiagOpts)
keymap("n", "<leader>vl", vim.diagnostic.open_float, DiagOpts)
-- keymap("n", "<leader>vq", vim.diagnostic.setloclist, DiagOpts) -- Listed for refernce only

vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("UserLspConfig", {}),

    callback = function(ev)
        local lsp_opts = { noremap = true, buffer = ev.buf }

        keymap("n", "gd", vim.lsp.buf.definition, lsp_opts)
        keymap("n", "gD", vim.lsp.buf.declaration, lsp_opts)
        keymap("n", "gI", vim.lsp.buf.implementation, lsp_opts)
        keymap("n", "gr", vim.lsp.buf.references, lsp_opts)
        keymap("n", "gT", vim.lsp.buf.type_definition, lsp_opts)

        keymap("n", "K", vim.lsp.buf.hover, lsp_opts)
        keymap("n", "<C-e>", vim.lsp.buf.signature_help, lsp_opts)

        keymap("n", "<leader>va", vim.lsp.buf.add_workspace_folder, lsp_opts)
        keymap("n", "<leader>vd", vim.lsp.buf.remove_workspace_folder, lsp_opts)

        keymap("n", "<leader>vf", function()
            print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
        end, lsp_opts)

        -- Does not work when mapped through an augroup
        -- Telescope can find these if needed
        -- keymap("n", "<leader>vs", vim.lsp.buf.workspace_symbol(), lsp_opts)

        keymap("n", "<leader>vr", vim.lsp.buf.rename, lsp_opts)

        keymap("n", "<leader>vc", vim.lsp.buf.code_action, lsp_opts)

        -- For reference only. Will uncomment if working with a formatter that does not support
        -- autoformat on save
        -- keymap("n", "<leader>vo", function()
        --     vim.lsp.buf.format { async = true }
        -- end, lsp_opts)
    end,
})

-------------------
-- Other Plugins --
-------------------

keymap("n", "<leader>nt", "<cmd>NvimTreeToggle<cr>", opts)

keymap("n", "<leader>it", "<cmd>TSPlaygroundToggle<cr>", opts)
keymap("n", "<leader>ih", "<cmd>TSHighlightCapturesUnderCursor<cr>", opts)

keymap("n", "<leader>eo", "<cmd>TSContextToggle<cr>", opts)

keymap("n", "<leader>b", "<cmd>TroubleToggle<cr>", opts)

keymap("n", "<leader>ut", "<cmd>UndotreeToggle<cr>", opts)

keymap("n", "<leader>me", "<cmd>MarkdownPreview<cr>", opts)
keymap("n", "<leader>ms", "<cmd>MarkdownPreviewStop<cr>", opts)
keymap("n", "<leader>mt", "<cmd>MarkdownPreviewToggle<cr>", opts)

keymap("n", "<leader>ot", "<cmd>ColorizerToggle<cr>", opts)
keymap("n", "<leader>oa", "<cmd>ColorizerAttachToBuffer<cr>", opts)
keymap("n", "<leader>od", "<cmd>ColorizerDetachFromBuffer<cr>", opts)
keymap("n", "<leader>or", "<cmd>ColorizerReloadAllBuffers<cr>", opts)
