vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, Opts)
vim.keymap.set("n", "]d", vim.diagnostic.goto_next, Opts)

vim.keymap.set("n", "[D", function()
    vim.diagnostic.goto_prev({ severity = "ERROR" })
end, Opts)

vim.keymap.set("n", "]D", function()
    vim.diagnostic.goto_next({ severity = "ERROR" })
end, Opts)

vim.keymap.set("n", "<leader>vl", vim.diagnostic.open_float, Opts)

local handler_border = {
    border = "single",
    style = "minimal",
}

vim.diagnostic.config({
    update_in_insert = false,
    severity_sort = true,
    float = { vim.fn.flatten({ handler_border, { source = "always" } }) },
})

-- LSP windows use floating windows, documented in nvim_open_win
-- The borders use the "FloatBorder" highlight group

vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, handler_border)

vim.lsp.handlers["textDocument/signatureHelp"] =
    vim.lsp.with(vim.lsp.handlers.signature_help, handler_border)

vim.lsp.set_log_level("ERROR")

vim.api.nvim_create_autocmd("LspAttach", {
    group = LSP_Augroup,
    callback = function(ev)
        local lsp_opts = { buffer = ev.buf }

        vim.keymap.set("n", "gd", vim.lsp.buf.definition, lsp_opts)
        vim.keymap.set("n", "gD", vim.lsp.buf.declaration, lsp_opts)
        vim.keymap.set("n", "gI", vim.lsp.buf.implementation, lsp_opts)
        vim.keymap.set("n", "gr", vim.lsp.buf.references, lsp_opts)
        vim.keymap.set("n", "gt", vim.lsp.buf.type_definition, lsp_opts)

        vim.keymap.set("n", "K", vim.lsp.buf.hover, lsp_opts)
        vim.keymap.set("n", "gs", vim.lsp.buf.signature_help, lsp_opts)

        vim.keymap.set("n", "<leader>va", vim.lsp.buf.add_workspace_folder, lsp_opts)
        vim.keymap.set("n", "<leader>vd", vim.lsp.buf.remove_workspace_folder, lsp_opts)

        vim.keymap.set("n", "<leader>vf", function()
            print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
        end, lsp_opts)

        vim.keymap.set("n", "<leader>vr", vim.lsp.buf.rename, lsp_opts)

        vim.keymap.set({ "n", "v" }, "<leader>vc", vim.lsp.buf.code_action, lsp_opts)
    end,
})

-- Leader q since this is a qf command
vim.keymap.set("n", "<leader>ql", function()
    local clients = vim.lsp.get_active_clients()

    if #clients == 0 then
        print("No active LSP clients")
        return
    end

    local for_qf_list = {}

    for _, client in ipairs(clients) do
        local bufs_for_client = "( "

        for _, buf in ipairs(vim.lsp.get_buffers_by_client_id(client.id)) do
            bufs_for_client = bufs_for_client .. buf .. " "
        end

        bufs_for_client = bufs_for_client .. ")"
        local lsp_entry = "LSP: "
            .. client.name
            .. ", ID: "
            .. client.id
            .. ", Buffer(s): "
            .. bufs_for_client
            .. ", Root: "
            .. (client.config.root_dir or "")
            .. ", Status: "
            .. (client.config.status or "")
            .. ", Command: "
            .. (client.config.cmd[1] or "")

        table.insert(for_qf_list, { text = lsp_entry })
    end

    vim.fn.setqflist(for_qf_list, "r")
    vim.cmd("copen")
    vim.cmd.wincmd("J")
end, Opts)
