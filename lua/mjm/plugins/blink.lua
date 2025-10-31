local api = vim.api

local function setup_blink()
    vim.keymap.set("i", "<C-y>", "<nop>")
    vim.keymap.set("i", "<C-n>", "<nop>")
    vim.keymap.set("i", "<C-p>", "<nop>")
    vim.keymap.set("i", "<M-y>", "<nop>")
    vim.keymap.set("i", "<M-n>", "<nop>")
    vim.keymap.set("i", "<M-p>", "<nop>")
    vim.keymap.set("i", "<M-s>", "<nop>")

    require("blink.cmp").setup({
        cmdline = {
            completion = { menu = { auto_show = true }, ghost_text = { enabled = false } },
            enabled = true,
            keymap = {
                preset = "inherit",
                ["<M-y>"] = false,
                ["<M-n>"] = false,
                ["<M-p>"] = false,
            },
            sources = { "cmdline" },
        },
        completion = {
            accept = { auto_brackets = { enabled = true } },
            documentation = {
                auto_show = true,
                auto_show_delay_ms = 125,
                window = { border = "single" },
            },
            list = { max_items = 20 },
            menu = {
                border = "single",
                draw = {
                    columns = { { "label" }, { "kind" }, { "source_name" } },
                    components = {
                        kind = {
                            highlight = function(ctx)
                                return ctx.kind and "BlinkCmpKind" .. ctx.kind or "BlinkCmpKind"
                            end,
                        },
                        source_name = { highlight = "Comment" },
                    },
                },
            },
        },
        fuzzy = {
            prebuilt_binaries = { download = false },
            sorts = { "exact", "score", "sort_text" },
        },
        keymap = {
            preset = "none",
            ["<C-e>"] = false,
            ["<C-E>"] = false,
            ["<C-p>"] = {
                function(cmp)
                    cmp.select_prev({ auto_insert = false })
                end,
            },
            ["<C-n>"] = {
                function(cmp)
                    cmp.select_next({ auto_insert = false })
                end,
            },
            ["<C-y>"] = { "select_and_accept" },
            ["<M-p>"] = { "scroll_documentation_up" },
            ["<M-n>"] = { "scroll_documentation_down" },
            ["<M-y>"] = {
                function(cmp)
                    if cmp.is_visible() then
                        cmp.hide()
                    else
                        cmp.show()
                    end
                end,
            },
            ["<M-s>"] = {
                function(cmp)
                    if cmp.is_signature_visible() then
                        cmp.hide_signature()
                    else
                        cmp.show_signature()
                    end
                end,
            },
        },
        signature = {
            enabled = true,
            window = {
                border = "single",
                direction_priority = { "n", "s" },
                show_documentation = true,
            },
        },
        sources = {
            default = { "lsp", "snippets", "buffer", "path" },
            per_filetype = {
                lua = { inherit_defaults = true, "lazydev" },
                sql = { "dadbod", "buffer", "path" },
                text = { "buffer", "path" },
            },
            providers = {
                buffer = {
                    enabled = true,
                    opts = {
                        get_bufnrs = function()
                            return vim.tbl_filter(function(bufnr)
                                return api.nvim_get_option_value("buftype", { buf = bufnr }) == ""
                            end, vim.api.nvim_list_bufs())
                        end,
                    },
                    score_offset = -6,
                    transform_items = function(a, items)
                        local ut = require("mjm.utils")
                        local prose_ft = { "text", "markdown" }
                        local ft = vim.api.nvim_get_option_value("filetype", { buf = 0 })
                        if not (vim.tbl_contains(prose_ft, ft) or ut.is_comment()) then
                            return items
                        end

                        local keyword = a.get_keyword()
                        local correct, case
                        if keyword:match("^%l") then
                            correct = "^%u%l+$"
                            case = string.lower
                        elseif keyword:match("^%u") then
                            correct = "^%l+$"
                            case = string.upper
                        else
                            return items
                        end

                        local seen = {}
                        local out = {}
                        for _, item in ipairs(items) do
                            local raw = item.insertText or ""
                            if raw:match(correct) then
                                local text = case(raw:sub(1, 1)) .. raw:sub(2)
                                item.insertText = text
                                item.label = text
                            end
                            if not seen[item.insertText] then
                                seen[item.insertText] = true
                                table.insert(out, item)
                            end
                        end

                        return out
                    end,
                },
                dadbod = { name = "Dadbod", module = "vim_dadbod_completion.blink" },
                lazydev = { module = "lazydev.integrations.blink", name = "LazyDev" },
                lsp = { fallbacks = {} },
                path = {
                    opts = {
                        get_cwd = function(_)
                            return vim.uv.cwd()
                        end,
                    },
                },
            },
        },
    })

    local groups = {
        BlinkCmpDocBorder = { link = "FloatBorder" },
        BlinkCmpMenuBorder = { link = "FloatBorder" },
        BlinkCmpSignatureHelpBorder = { link = "FloatBorder" },

        BlinkCmpKindClass = { link = "Type" },
        BlinkCmpKindColor = { link = "DiagnosticWarn" },
        BlinkCmpKindConstant = { link = "Constant" },
        BlinkCmpKindConstructor = { link = "Special" },
        BlinkCmpKindEnum = { link = "Type" },
        BlinkCmpKindEnumMember = { link = "@lsp.type.enumMember" },
        BlinkCmpKindEvent = { link = "Function" },
        BlinkCmpKindFolder = { link = "Directory" },
        BlinkCmpKindFunction = { link = "Function" },
        BlinkCmpKindInterface = { link = "Type" },
        BlinkCmpKindKeyword = { link = "Special" },
        BlinkCmpKindMethod = { link = "Function" },
        BlinkCmpKindModule = { link = "@module" },
        BlinkCmpKindOperator = { link = "Operator" },
        BlinkCmpKindSnippet = { link = "Special" },
        BlinkCmpKindStruct = { link = "Type" },
        BlinkCmpKindText = { link = "String" },
        BlinkCmpKindUnit = { link = "Number" },
        BlinkCmpKindValue = { link = "String" },

        BlinkCmpKindTypeParameter = { link = "Type" },
    } ---@type { string: vim.api.keyset.highlight }

    for k, v in pairs(groups) do
        vim.api.nvim_set_hl(0, k, v)
    end
end

vim.api.nvim_create_autocmd({ "CmdlineEnter", "BufReadPre", "BufNewFile" }, {
    group = vim.api.nvim_create_augroup("setup-blink", { clear = true }),
    once = true,
    callback = function()
        local path = nil ---@type string
        for _, s in pairs(vim.pack.get()) do
            if s.spec.name == "blink.cmp" then
                path = s.path
                break
            end
        end

        if not path then
            local msg = "blink.cmp path not found. Cannot build fuzzy" ---@type string
            vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, {})
            return
        end

        local cmd = { "cargo", "+nightly", "build", "--release" } ---@type string[]
        local sys_opts = { cwd = path, text = true } ---@type vim.SystemOpts
        vim.api.nvim_echo({ { "Building fuzzy for blink.cmp...", "" } }, true, {})

        vim.system(cmd, sys_opts, function(out)
            if out.code == 0 then
                vim.schedule(function()
                    vim.api.nvim_echo({ { "", "" } }, false, {})
                    setup_blink()
                end)

                return
            end

            vim.schedule(function()
                local msg = out.stderr or "Unknown error building fuzzy for blink" ---@type string
                vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
            end)
        end)

        vim.api.nvim_del_augroup_by_name("setup-blink")
    end,
})
