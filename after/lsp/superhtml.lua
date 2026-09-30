return {
    on_init = function(client)
        local c = client.server_capabilities
        c.completionProvider = nil
        c.referencesProvider = nil
    end,
}
