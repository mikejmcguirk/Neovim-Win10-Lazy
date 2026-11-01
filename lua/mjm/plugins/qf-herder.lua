return {
    -- dir = "~/Documents/nvim-plugin-dev/nvim-qf-herder/",
    "mikejmcguirk/nvim-qf-herder",
    lazy = false,
    init = function()
        vim.g.qf_herder = {
            nav = {
                on_nav = function(keep_focus)
                    if not keep_focus then
                        vim.api.nvim_cmd({ cmd = "norm", args = { "zzze" }, bang = true })
                    end
                end,
            },
        }
    end,
}
