local api = vim.api
local fn = vim.fn
local fs = vim.fs
local img_dir = "assets/img"

return {
    "HakonHarnes/img-clip.nvim",
    opts = {
        default = {
            dir_path = img_dir,
            extension = "png",
            file_name = function()
                local root = vim.uv.cwd() ---@type string|nil
                if not root then
                    return
                end

                local basename = fs.basename(api.nvim_buf_get_name(0))
                local name = fn.fnamemodify(basename, ":r")

                local pattern = fs.joinpath(root, img_dir, name) .. "*"
                local files = fn.glob(pattern, false, true) ---@type string[]

                return name .. "_" .. string.format("%03d", #files + 1)
            end,
            insert_mode_after_paste = false,
            prompt_for_file_name = false,
        },
        filetypes = { markdown = { template = "![$LABEL]($FILE_PATH)" } },
    },
    init = function()
        api.nvim_create_autocmd("FileType", {
            group = api.nvim_create_augroup("mjm-map-img-clip", {}),
            pattern = "markdown",
            callback = function(ev)
                vim.keymap.set("n", "<localleader>p", function()
                    api.nvim_cmd({ cmd = "PasteImage" }, {})
                end, { buf = ev.buf })
            end,
        })
    end,
}
