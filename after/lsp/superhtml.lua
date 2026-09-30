return {
    on_init = function(client)
        local c = client.server_capabilities
        c.completionProvider = nil
        c.referencesProvider = nil

        vim.lsp.linked_editing_range.enable(true, { client_id = client.id })
    end,
}
