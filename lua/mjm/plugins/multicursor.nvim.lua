return {
    "jake-stewart/multicursor.nvim",
    branch = "1.0",
    config = function()
        local mc = require("multicursor-nvim")
        local del = vim.keymap.del
        local set = vim.keymap.set

        mc.setup()
        local nocursor_maps = {
            { { "n", "x" }, "gii", mc.restoreCursors },
            { { "n", "x" }, "giC", mc.addCursor },
        } ---@type { [1]:string[], [2]:string, [3]:function }

        ---@return nil
        local function map_nocursor()
            for _, map in ipairs(nocursor_maps) do
                for _, mode in ipairs(map[1]) do
                    set(mode, map[2], map[3])
                end
            end
        end

        ---@return nil
        local function del_nocursor()
            for _, map in ipairs(nocursor_maps) do
                for _, mode in ipairs(map[1]) do
                    if vim.fn.maparg(map[2], mode) ~= "" then del(mode, map[2]) end
                end
            end
        end

        map_nocursor()
        set({ "n", "x" }, "gic", mc.addCursor)
        set("x", "I", function()
            if string.sub(vim.api.nvim_get_mode().mode, 1, 1) ~= "\22" then mc.insertVisual() end
        end)

        set("x", "A", function()
            if string.sub(vim.api.nvim_get_mode().mode, 1, 1) ~= "\22" then mc.appendVisual() end
        end)

        -- MAYBE: <C-s> in normal mode, then s/S/<M-s> in visual. But where does nvim-surround 'S'
        -- go? Also, anti-pattern for substitute to not be in visual
        set("n", "gis", mc.matchAllAddCursors)
        set("x", "gis", mc.matchCursors)
        set("x", "giS", mc.splitCursors)
        set("x", "gi<M-s>", function()
            mc.matchCursors("[^[:space:]].*$")
        end, { desc = "Create a cursor for each visual line" }) -- Credit: stevearc

        -- MAYBE: <C-/> or <M-/>
        set({ "n", "x" }, "gi/", mc.searchAllAddCursors)
        -- LOW: Unsure why searchAddCursor always sets v:searchforward to 1.
        -- search() does not do this
        -- MAYBE: Could be <C-n> and <M-n>
        set({ "n", "x" }, "gin", function()
            local sf = vim.v.searchforward
            mc.searchAddCursor(sf == 1 and 1 or -1)
            vim.v.searchforward = sf
        end)

        set({ "n", "x" }, "giN", function()
            local sf = vim.v.searchforward
            mc.searchAddCursor(sf == 1 and -1 or 1)
            vim.v.searchforward = sf
        end)

        set({ "n", "x" }, "<up>", function()
            mc.lineAddCursor(-1)
        end)

        set({ "n", "x" }, "<down>", function()
            mc.lineAddCursor(1)
        end)

        set({ "n", "x" }, "<C-up>", function()
            mc.lineSkipCursor(-1)
        end)

        set({ "n", "x" }, "<C-down>", function()
            mc.lineSkipCursor(1)
        end)

        set({ "n", "x" }, "<S-up>", function()
            mc.matchAddCursor(-1)
        end)

        set({ "n", "x" }, "<S-down>", function()
            mc.matchAddCursor(1)
        end)

        set({ "n", "x" }, "<M-up>", function()
            mc.matchSkipCursor(-1)
        end)

        set({ "n", "x" }, "<M-down>", function()
            mc.matchSkipCursor(1)
        end)

        mc.addKeymapLayer(function(layerSet)
            del_nocursor()

            layerSet({ "n", "x" }, "<C-r>", "<nop>")
            layerSet({ "n", "x" }, "u", "<nop>")
            layerSet({ "n", "x" }, "<C-i>", mc.jumpForward)
            layerSet({ "n", "x" }, "<C-o>", mc.jumpBackward)
            layerSet("n", "<esc>", function()
                mc.clearCursors()
                map_nocursor()
            end)

            layerSet({ "n", "x" }, "n", function()
                local sf = vim.v.searchforward
                mc.searchSkipCursor(sf == 1 and 1 or -1)
                vim.v.searchforward = sf
            end)

            layerSet({ "n", "x" }, "N", function()
                local sf = vim.v.searchforward
                mc.searchSkipCursor(sf == 1 and -1 or 1)
                vim.v.searchforward = sf
            end)

            layerSet({ "n", "x" }, "gii", function()
                if mc.cursorsEnabled() then
                    mc.disableCursors()
                else
                    mc.enableCursors()
                end
            end)

            layerSet({ "n", "x" }, "<left>", mc.prevCursor)
            layerSet({ "n", "x" }, "<right>", mc.nextCursor)
            layerSet({ "n", "x" }, "<S-left>", mc.firstCursor)
            layerSet({ "n", "x" }, "<S-right>", mc.lastCursor)

            -- Automatically leaves visual mode. Map in normal only
            set("n", "giu", mc.duplicateCursors)
            set({ "n", "x" }, "giC", function()
                mc.addCursor()
                if not mc.cursorsEnabled() then mc.enableCursors() end
            end, { desc = "Add a new cursor" })

            ---@param toggle_enable boolean
            ---@return nil
            local function del_cursor(toggle_enable)
                if mc.cursorsEnabled() then
                    mc.deleteCursor()
                    if toggle_enable then mc.disableCursors() end
                else
                    mc.action(function(ctx)
                        local mainCursor = ctx:mainCursor()
                        local cursor = mainCursor:overlappedCursor()
                        if cursor then cursor:delete() end
                    end)

                    if toggle_enable then mc.enableCursors() end
                end
            end

            -- MAYBE: <C-,> or <M-,>
            layerSet({ "n", "x" }, "gid", function()
                del_cursor(false)
            end)

            -- MAYBE: <C-,> or <M-,>
            layerSet({ "n", "x" }, "giD", function()
                del_cursor(true)
            end)

            layerSet("x", "(", function()
                mc.swapCursors(-1)
            end)

            layerSet("x", ")", function()
                mc.swapCursors(1)
            end)

            layerSet("x", "<M-(>", function()
                mc.transposeCursors(-1)
            end)

            layerSet("x", "<M-)>", function()
                mc.transposeCursors(1)
            end)

            -- MAYBE: Use &, but that assumes substitute will be broken forever
            layerSet("n", "gi&", mc.alignCursors) -- Does not work in visual mode
            -- MAYBE: <M-a> and <M-x>
            layerSet({ "n", "x" }, "gi<C-a>", mc.sequenceDecrement)
            layerSet({ "n", "x" }, "gi<C-x>", mc.sequenceIncrement, { desc = "foo" })
        end)
    end,
}

-- LOW: More clear upward and downward arrows for cursor offscreen

-- MAYBE: Map toggleCursor. But where does it go + how to capture all gic/gid behaviors?
-- MAYBE: Map addCursorOperator. My initial test of this though didn't yield great results
-- MAYBE: Add a map for skipCursor. Assuming same issues as addCursorOperator though

-- BASELINE: Would need alternatives to the alt and shift mappings

-- LIMITATIONS:
-- - If you run a substitute cmd, it does not apply to all lines with cursors
-- - Undo/redo behavior is inconsistent
-- - Only built-in insert mode navigation seems to work. Keymaps or <C-o> navigation are
--   inconsistent
-- - Results with ts-text-objects are inconsistent
