local api = vim.api
local ut = Mjm_Defer_Require("mjm.utils") ---@type MjmUtils

---@module 'blink.cmp'
---@type blink.cmp.Config
local blink_opts = {
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
                        end, api.nvim_list_bufs())
                    end,
                },
                score_offset = -6,
                transform_items = function(a, items)
                    local prose_ft = { "text", "markdown" }
                    local ft = api.nvim_get_option_value("filetype", { buf = 0 })
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
                            out[#out + 1] = item
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
}

---@return nil
local function setup_blink()
    require("blink-cmp").setup(blink_opts)

    vim.keymap.set("i", "<C-y>", "<nop>")
    vim.keymap.set("i", "<C-n>", "<nop>")
    vim.keymap.set("i", "<C-p>", "<nop>")
    vim.keymap.set("i", "<M-y>", "<nop>")
    vim.keymap.set("i", "<M-n>", "<nop>")
    vim.keymap.set("i", "<M-p>", "<nop>")
    vim.keymap.set("i", "<M-s>", "<nop>")

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
        api.nvim_set_hl(0, k, v)
    end
end

-- blink's /plugin file updates the default lspconfig and needs to be eager loaded. The setup
-- function takes a non-trivial amount of time to run, is dependent on other environmental setup,
-- and does not promulgate environmental setup itself. Eager load the plugin, but manually tuck
-- running the setup function into an autocmd
return {
    "saghen/blink.cmp",
    lazy = false,
    dependencies = {
        "rafamadriz/friendly-snippets",
        "https://github.com/kristijanhusak/vim-dadbod-completion",
    },
    version = "1.*",
    build = "cargo +nightly build --release",
    init = function()
        api.nvim_create_autocmd("InsertEnter", {
            group = api.nvim_create_augroup("setup-blink", {}),
            once = true,
            callback = setup_blink,
        })
    end,
}

-- LOW: blink-cmp-words creates blocking calls and the other dictionary plugin creates hanging
-- fzf processes, so, if we want a dictionary, we have to make it
