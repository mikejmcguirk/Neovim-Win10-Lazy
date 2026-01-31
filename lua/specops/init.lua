local api = vim.api

-- local old_report ---@type integer|nil
local old_cur_pos ---@type { [1]: integer, [2]: integer }|nil

local Spec_Ops = {}

-- TODO: Opt for disabling the report set
-- TODO: Opt for disabling the cursor hold
function Spec_Ops.yank()
    -- old_report = api.nvim_get_option_value("report", { scope = "global" })
    if vim.v.register ~= "_" then
        old_cur_pos = api.nvim_win_get_cursor(0)
    end

    return "y"
end

-- function Spec_Ops.delete()
--     old_report = api.nvim_get_option_value("report", { scope = "global" })
--     api.nvim_set_option_value("report", 9999, { scope = "global" })
--     return "d"
-- end

-- function Spec_Ops.change()
--     old_report = api.nvim_get_option_value("report", { scope = "global" })
--     api.nvim_set_option_value("report", 9999, { scope = "global" })
--     return "c"
-- end

local group = api.nvim_create_augroup("specops", {})
api.nvim_create_autocmd("TextYankPost", {
    group = group,
    callback = function()
        if vim.v.event.operator ~= "y" then
            return
        end

        -- if old_report then
        --     api.nvim_set_option_value("report", old_report, { scope = "global" })
        --     old_report = nil
        -- end

        if old_cur_pos then
            api.nvim_win_set_cursor(0, old_cur_pos)
            old_cur_pos = nil
        end
    end,
})

-- TODO: does not handle, for example, "dl" on a blank line
-- TODO: Do I just set report=9999 as a default option and move on from this? Issue - report is
-- useful with substitute

-- api.nvim_create_autocmd("TextChanged", {
--     group = group,
--     callback = function()
--         local op = vim.v.operator
--         if (op == "d" or op == "c") and old_report then
--             api.nvim_set_option_value("report", old_report, { scope = "global" })
--             old_report = nil
--         end
--     end,
-- })

return Spec_Ops

-- TODO: See if ui_attach is better for intercepting the lines yanked messages than altering the
-- report option
-- TODO: For convenience, provide separate Eol <Plug> maps. Should not need to be necessary to
-- create separate APIs for them though
-- TODO: Review the old spec ops code for features to transfer over
-- TODO: The basic wrappers do not in and of themselves justify a plugin. They have to be a part
-- of the whole package
-- TODO: For yank/change/delete, the reg bookkeeping needs to be built around the built-in ops
-- - See how yanky does it. Unsure if there are other alternatives to look at
-- - Same idea as the old spec-ops: default, target only, or ring
-- - Might be in the old code but forgotten, how to handle no default clipboard vs unnamed vs
-- unnamedplus
-- TODO: Design point - Avoid "vendor lock in" as much as possible. Users should be able to keep
-- their hl.on_yank autocmds without issue. If a user wants to use the on_paste hl without using
-- the specops mapping, that should also be possible. If the user wants to make convenience
-- mappings to certain registers, that needs to be possible with the functions/plugs. Spec-Ops
-- should not insist on itself
-- TODO: Paste highlight
-- TODO: Linewise paste should auto-indent
-- TODO: Mapping to center based on a motion/text object. We'll say zu for the moment since that's
-- the closest opening there is. So you should be able to do zuiw and it will move the cursor to
-- the iw and zz. More importantly, you could do something like zuim and it would move the cursor
-- to the center of the function and zz. Simple enough logic - Get boundaries, calculate center,
-- move cursor, norm zz. Better mapping: zZ. No default. No conflict. Logic. This is not a high
-- enough value function to demand premium real-estate.
--
-- TODO: Implement the emacs yank cycling function with [y]y as the keys
-- TODO: As before, implementing substitute and and repeat are mandatory
