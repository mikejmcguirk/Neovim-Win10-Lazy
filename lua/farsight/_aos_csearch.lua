local api = vim.api

-------------------------------------
-- MARK: Namespaces and Highlights --
-------------------------------------

local ns_basename = "farsight.csearch"
local state_ns_dim = api.nvim_create_namespace(ns_basename .. ".dim")
local state_ns_labels = api.nvim_create_namespace(ns_basename .. ".labels")

do
    -- TODO-DEP: Remove this when 0.14 comes out.
    api.nvim_set_hl(0, "Dimmed", { default = true, link = "Comment" })

    api.nvim_set_hl(0, "farsightCsearchDim", { default = true, link = "Dimmed" })
    api.nvim_set_hl(0, "farsightCsearchLabel1st", { default = true, link = "IncSearch" })
    api.nvim_set_hl(0, "farsightCsearchLabel2nd", { default = true, link = "CurSearch" })
    api.nvim_set_hl(0, "farsightCsearchLabel3rd", { default = true, link = "Search" })
end

local hl_error = api.nvim_get_hl_id_by_name("ErrorMsg")

local hl_dim = api.nvim_get_hl_id_by_name("farsightCsearchDim")
local hl_label_1 = api.nvim_get_hl_id_by_name("farsightCsearchLabel1st")
local hl_label_2 = api.nvim_get_hl_id_by_name("farsightCsearchLabel2nd")
local hl_label_3 = api.nvim_get_hl_id_by_name("farsightCsearchLabel3rd")

local hl_priority_dim = vim.hl.priorities.user + 50
local hl_priority_label = hl_priority_dim + 1
