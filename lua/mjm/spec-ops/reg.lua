--small delete is normal only
-- use the modulo loop to cycle registers

---------------
-- Behaviors --
---------------

-- Default:
--   - Yank to the default unless a register is specified
--   - Also place in reg 0 (or 1, whatever)
--   - Bump reg history

local utils = require("mjm.spec-ops.utils")

local M

--- @class reg_ctx
--- @field lines string[]
--- @field op string
--- @field reg string
--- @field vmode boolean

--- @type { reg_handler: fun( ctx: reg_ctx): string[] }
local reg_config = {}

-- TODO: Weird question - Do we handle reg validity here or in the ops? If you do it here, anyone
-- who wants to make a custom handler has to do it themselves. But if you don't, then you're
-- firing and forgetting the register. You're relying on spooky action at a distance

-- PERF: I have table extends here for clarity, but they are unnecessary heap allocations
-- Same with inlining the delete_cmds table instead of storing it persistently
-- Same with creating locals for every part of ctx
--- @param ctx reg_ctx
--- @return string[]
function M.default_handler(ctx)
    ctx = ctx or {}

    local default_reg = utils.get_default_reg() --- @type string
    local reg = (function()
        if utils.is_valid_register(ctx.reg) then
            return ctx.reg
        else
            return default_reg
        end
    end)() --- @type string

    if reg == "_" then
        return { reg }
    end

    ctx.op = ctx.op or "y"
    ctx.lines = ctx.lines or { "" } -- Fallback should not trigger a ring movement on delete

    local to_overwrite = { '"' }
    if reg ~= '"' then
        vim.tbl_extend("force", to_overwrite, reg)
    end

    if vim.tbl_contains({ "d", "c" }, ctx.op) and not ctx.vmode then
        if #ctx.lines == 1 and reg ~= default_reg then
            -- NOTE: per :h registers, the "1" register is used in addition to the small delete
            -- register if certain motions are used. I am not sure how to check for those motions
            -- without remapping multiple default operators or using a gluttonous amount of
            -- autocmds. For simplicity, only use the small delete register on one-liners
            -- CORE: When leaving operator pending mode, it would be useful to be able to access
            -- what operator was used
            return vim.tbl_extend("force", to_overwrite, { "-" })
        else
            -- NOTE; Unfortunate if the calling function errors after this, but don't want to
            -- spread out the behavior and make things confusing
            for i = 9, 2, -1 do
                local old_reg = vim.fn.getreginfo(tostring(i - 1))
                vim.fn.setreg(tostring(i), old_reg.regcontents, old_reg.regtype)
            end

            return vim.tbl_extend("force", to_overwrite, { "1" })
        end
    end

    if reg == default_reg then
        return vim.tbl_extend("force", to_overwrite, { "0" })
    else
        return to_overwrite
    end
end

--- @param ctx reg_ctx
--- @return string[]
function M.target_only_handler(ctx)
    ctx = ctx or {}

    if utils.is_valid_register(ctx.reg) then
        return { ctx.reg }
    else
        return { utils.get_default_reg() }
    end
end

return M
