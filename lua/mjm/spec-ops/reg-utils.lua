local blk_utils = require("mjm.spec-ops.block-utils")

---------------
-- Behaviors --
---------------

local utils = require("mjm.spec-ops.utils")

local M = {}

--- @class reg_handler_ctx
--- @field lines? string[]
--- @field op string "y"|"p"|"d"
--- @field reg string
--- @field vmode boolean

--- @class reg_info
--- @field reg string
--- @field lines string[]
--- @field type string
--- @field vtype string

-- TODO: Weird question - Do we handle reg validity here or in the ops? If you do it here, anyone
-- who wants to make a custom handler has to do it themselves. But if you don't, then you're
-- firing and forgetting the register. You're relying on spooky action at a distance

-- PERF: I have table extends here for clarity, but they are unnecessary heap allocations
-- Same with inlining the delete_cmds table instead of storing it persistently
-- Same with creating locals for every part of ctx

--- @param ctx reg_handler_ctx
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
        table.insert(to_overwrite, reg)
    end

    if ctx.op == "d" and not ctx.vmode then
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

            table.insert(to_overwrite, "1")
            return to_overwrite
        end
    end

    if reg == default_reg then
        table.insert(to_overwrite, "0")
        return to_overwrite
    else
        return to_overwrite
    end
end

--- @param ctx reg_handler_ctx
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

--- @param ctx reg_handler_ctx
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

local function regtype_from_vtype(vtype)
    local short_vtype = string.sub(vtype, 1, 1)
    if short_vtype == "\22" then
        local width = string.sub(vtype, 2, #vtype)
        return "b" .. width
    elseif short_vtype == "V" then
        return "l"
    else
        return "c"
    end
end

-- TODO: Need to clamp paste returns to one here
-- TODO: If we do it this way, try to stay out of doing it as text entirely

--- @param op_state op_state
--- @return reg_info[]
--- Returns an empty table if the black hole is passed to it
function M.get_reg_info(op_state)
    -- TODO: Remove this. Right now though the other ops depend on the old method
    local reg_handler_ctx = {
        lines = op_state.post.lines,
        op = op_state.pre.op_type,
        reg = op_state.post.reg,
        vmode = op_state.post.vmode,
    }
    local reges = op_state.pre.reg_handler(reg_handler_ctx) --- @type string[]
    local r = {} --- @type reg_info[]

    if vim.tbl_contains(reges, "_") then
        return r
    end

    for _, reg in pairs(reges) do
        local reginfo = vim.fn.getreginfo(reg)
        local lines = reginfo.regcontents
        local vtype = reginfo.regtype
        local type = regtype_from_vtype(vtype)

        table.insert(r, { reg = reg, lines = lines, type = type, vtype = vtype })
    end

    return r
end

--- @param op_state op_state
--- @return boolean
--- This function assumes that, if the black hole register was specified, it will receive an
--- empty op_state.post.reg_info table
function M.set_reges(op_state)
    local reg_info = op_state.post.reg_info or {} --- @type reg_info[]
    if (not reg_info) or #reg_info < 1 then
        return false
    end

    local lines = op_state.post.lines or { "" }
    local motion = op_state.post.motion or "char"

    local text = table.concat(lines, "\n") .. (motion == "line" and "\n" or "") --- @type string
    local regtype = (function()
        if motion == "block" then
            return "b" .. blk_utils.get_block_reg_width(lines) or nil
        elseif motion == "line" then
            return "l"
        else
            return "c"
        end
    end)()

    for _, reg in pairs(reg_info) do
        vim.fn.setreg(reg.reg, text, regtype)
    end

    return true
end
return M
