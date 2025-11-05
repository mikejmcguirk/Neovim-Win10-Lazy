local fs = vim.fs
local img_dir = "assets/img" ---@type string

return {
    "HakonHarnes/img-clip.nvim",
    event = "VeryLazy",
    opts = {
        default = {
            dir_path = img_dir,
            extension = "png",
            file_name = function()
                local root = vim.uv.cwd() ---@type string|nil
                if not root then return end
                local basename = fs.basename(vim.api.nvim_buf_get_name(0)) ---@type string
                local name = require("mjm.utils").fname_root(basename) ---@type string
                local pattern = fs.joinpath(root, img_dir, name) .. "*" ---@type string

                local files = vim.fn.glob(pattern, false, true) ---@type string[]
                return name .. "_" .. string.format("%03d", #files)
            end,
            insert_mode_after_paste = false,
            prompt_for_file_name = false,
        },
        filetypes = { markdown = { template = "![$LABEL]($FILE_PATH)" } },
    },
    keys = { { "<leader>cp", "<cmd>PasteImage<cr>", mode = "n" } },
}
