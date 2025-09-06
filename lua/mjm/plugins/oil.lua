-- MAYBE: stevearc does not recommend lazy loading because of the difficulty of handing all
-- the cases. Can see why in terms of stuff like edit. On the other hand, it doesn't look like
-- anything in the code precludes doing this
-- FUTURE: the . function in vinegar to pre-populate the file at the end of the cmdline could be
-- useful

local oil = require("oil")

local function close_oil()
    if vim.api.nvim_get_option_value("modified", { buf = 0 }) then
        vim.notify("Oil buffer has unsaved changes")
        return
    end

    oil.close()
end

oil.setup({
    columns = { "size", "permissions" },
    watch_for_changes = true,
    keymaps = {
        ["`"] = { "actions.parent", mode = "n" }, --- Patternful with vinegar mapping
        ["~"] = { "actions.open_cwd", mode = "n" }, --- Vinegar style mapping
        ["-"] = { close_oil, mode = "n" },
        ["+"] = { close_oil, mode = "n" },
        ["<C-^>"] = { close_oil, mode = "n" },
        ["q"] = {
            function()
                oil.discard_all_changes()
                oil.close()
            end,
            mode = "n",
        },
        ["Q"] = {
            function()
                oil.save({ confirm = nil }, function(err)
                    if err then
                        if err ~= "Canceled" then vim.notify(err, vim.log.levels.ERROR) end

                        return
                    end

                    oil.close()
                end)
            end,
            mode = "n",
        },
        ["<C-c>"] = false,
        ["_"] = false,
    },
    view_options = { show_hidden = true },
    float = { border = "single", padding = 3 },
    ssh = { border = "single" },
    keymaps_help = { border = "single" },
})

Map("n", "-", function() oil.open_float() end)

Map("n", "+", function() oil.open_float(vim.fn.getcwd()) end)
