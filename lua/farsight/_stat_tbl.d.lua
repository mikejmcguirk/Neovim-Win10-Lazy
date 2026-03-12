---@meta
error("Cannot require a meta file")

---@class (exact) farsight.meta.StatData
---@field pos_idxs integer[]
StatData = {}

---@return integer
function StatData:get_len() end

---Returns pos_idx at stat table position idx
---@param idx integer
---@return integer
function StatData:get_pos_idx(idx) end

---Returns resolved idx
---@param idx integer
---@param pos_idx integer
---@param ... any
---@return integer
function StatData:insert_at(idx, pos_idx, ...) end
