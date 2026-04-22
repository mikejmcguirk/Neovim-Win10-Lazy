local M = {}

-- TODO: My initial judgment here was wrong. A lot of the buf config logic needs to be moved here,
-- since it's basically adding bespoke logic to the buf accessor
-- The only thing I think buf config *needs* is a way to see the buf list, since that's
-- hidden behind _configs

function M.check()
    vim.health.start("nvim-tools Config")

    local nvim_tools = require("nvim-tools")
    local clean_cfg = nvim_tools.config()
    local main_errors = nvim_tools.config:validate(nil)

    if not main_errors or #main_errors == 0 then
        vim.health.ok("Global config is valid")
    else
        vim.health.error("Global config validation failed:")
        for _, err in ipairs(main_errors) do
            vim.health.error("  " .. err)
        end
    end

    vim.health.info("Current global config:")
    vim.health.info(vim.inspect(clean_cfg))

    vim.health.start("nvim-tools Per-Buffer Config")
    local buf_config = nvim_tools.buf_config
    local bufs = buf_config:list_bufs()
    if #bufs == 0 then
        vim.health.info("No per-buffer configs active")
        return
    end

    local empty_buf_configs = {} ---@type integer[]
    for _, buf in ipairs(bufs) do
        if not nvim_tools.buf_config[buf]:has_config() then
            empty_buf_configs[#empty_buf_configs + 1] = buf
        end
    end

    if #empty_buf_configs > 0 then
        local ntl = require("nvim-tools.list")
        ntl.filter(bufs, function(b)
            return not ntl.find(empty_buf_configs, b)
        end)

        local fmt_str = "Empty per-buffer config(s) detected on %d buffer(s): %s\n"
            .. "Run `require('nvim-tools').buf_config:clear()` to remove them."
        local empty_concat = table.concat(empty_buf_configs, ", ")
        local msg = string.format(fmt_str, #empty_buf_configs, empty_concat)
        vim.health.warn(msg)

        if #bufs == 0 then
            return
        end
    end

    local fmt_str = "Active per-buffer configs on %d buffer(s): %s"
    local bufs_str = string.format(fmt_str, #bufs, table.concat(bufs, ", "))
    vim.health.info(bufs_str)

    local buf_err_info = {} ---@type table<integer, string[]>
    for _, buf in ipairs(bufs) do
        local this_buf_config = buf_config[buf] ---@type nvim-tools.init.Config
        local errs = this_buf_config:validate(nil)
        if #errs > 0 then
            buf_err_info[buf] = errs
        end
    end

    if #require("nvim-tools.table").keys(buf_err_info) == 0 then
        vim.health.ok("All buffer configs are valid")
        return
    end

    for _, buf in ipairs(bufs) do
        local errs = buf_err_info[buf]
        if errs then
            vim.health.error(string.format("Buffer %d config validation failed:", buf))
            for _, err in ipairs(errs) do
                vim.health.error("  " .. err)
            end
        end
    end
end

return M
