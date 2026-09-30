return {
    on_init = function(client)
        local c = client.server_capabilities
        c.hoverProvider = nil
        c.documentHighlightProvider = nil
        c.linkedEditingRangeProvider = nil
        c.renameProvider = nil
    end,
}
