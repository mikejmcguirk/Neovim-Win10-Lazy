local api = vim.api

---@class farsight.highlighting.DimHlInfo
---@field [1] integer Length
---@field [2] integer[] Start Rows
---@field [3] integer[] Fin Rows

local M = {}

function M.checked_set_dim_extmarks(buf, ns, hl_id, dim_hl_info, dim)
    if not (dim_hl_info and dim) then
        return
    end

    local dim_rows = dim_hl_info[2]
    local dim_fin_rows = dim_hl_info[3]

    local extmark_opts = {
        end_col = 0,
        hl_eol = true,
        hl_group = hl_id,
        priority = 998,
    }

    local len_dim_hl_info = dim_hl_info[1]
    for i = 1, len_dim_hl_info do
        extmark_opts.end_row = dim_fin_rows[i] + 1
        api.nvim_buf_set_extmark(buf, ns, dim_rows[i], 0, extmark_opts)
    end
end

return M

-- TODO: Build out this module based on the actual use cases.
-- - With search, I'm still not sure what happens when the highlighting and labeling data diverge
-- - With jump, I'm not sure how the new data formats will play out
-- - Same with csearch
