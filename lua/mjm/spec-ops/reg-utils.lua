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

-- TODO: Weird question - Do we handle reg validity here or in the ops? If you do it here, anyone
-- who wants to make a custom handler has to do it themselves. But if you don't, then you're
-- firing and forgetting the register. You're relying on spooky action at a distance

-- PERF: I have table extends here for clarity, but they are unnecessary heap allocations
-- Same with inlining the delete_cmds table instead of storing it persistently
-- Same with creating locals for every part of ctx

--- @param ctx reg_ctx
--- @return string[]
---  See :h registers
---  If ctx.op is "p", will return ctx.reg or a fallback
---  For op values of "y", "c", and "d", will calculate a combination of registers to write to
---  in line with Neovim's defaults
---  If ctx.reg is the black hole, simply returns that value
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

    ctx.op = ctx.op or "p"
    if reg == "_" or ctx.op == "p" then
        return { reg }
    end

    ctx.lines = ctx.lines or { "" } -- Fallback should not trigger a ring movement on delete

    local to_overwrite = { '"' }
    if reg ~= '"' then
        vim.tbl_extend("force", to_overwrite, reg)
    end

    if vim.tbl_contains({ "d", "c" }, ctx.op) and not ctx.vmode then
        if #ctx.lines == 1 and reg ~= default_reg then
            -- Known issue: When certain motions are used, the 1 register is written in addition
            -- to the small delete register. That behavior is omitted
            -- CORE: Would be useful to see the last omode text object/motion
            return vim.tbl_extend("force", to_overwrite, { "-" })
        else
            -- NOTE: The possibility of the calling function erroring after this is run is
            -- accepted in order to keep register behavior centralized
            for i = 9, 2, -1 do
                local old_reg = vim.fn.getreginfo(tostring(i - 1)) --- @type table
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
--- Validates ctx.reg, returning either it or a fallback to the default reg
function M.target_only_handler(ctx)
    ctx = ctx or {}

    if utils.is_valid_register(ctx.reg) then
        return { ctx.reg }
    else
        return { utils.get_default_reg() }
    end
end

--- @param ctx reg_ctx
--- @return string[]
--- If yanking, changing, or deleting (ctx.op "y", "c", or "d"), write a copy to reg 0,
--- incrementing the other numbered registers to store history
--- Will only return the input register if it is the black hole or is a numbered register
--- Pasting (ctx.op "p") will not advance the ring
function M.ring_handler(ctx)
    ctx = ctx or {}

    local reg = (function()
        if utils.is_valid_register(ctx.reg) then
            return ctx.reg
        else
            return utils.get_default_reg()
        end
    end)() --- @type string

    if reg == "_" or reg:match("^%d$") or ctx.op == "p" then
        return { reg }
    end

    for i = 9, 1, -1 do
        local old_reg = vim.fn.getreginfo(tostring(i - 1)) --- @type table
        vim.fn.setreg(tostring(i), old_reg.regcontents, old_reg.regtype)
    end

    return { reg, "0" }
end

--- @param opt? string
function M.get_handler(opt)
    opt = opt or ""

    if opt == "target_only" then
        return M.target_only_handler
    elseif opt == "ring" then
        return M.ring_handler
    else
        return M.default_handler
    end
end

return M
