local function setup_blink()
    -- Don't want any mis-fires
    Map("i", "<C-y>", "<nop>")
    Map("i", "<C-n>", "<nop>")
    Map("i", "<C-p>", "<nop>")
    Map("i", "<M-y>", "<nop>")
    Map("i", "<M-n>", "<nop>")
    Map("i", "<M-p>", "<nop>")
    Map("i", "<M-s>", "<nop>")

    require("blink.cmp").setup({
        cmdline = {
            completion = { menu = { auto_show = true }, ghost_text = { enabled = false } },
            enabled = true,
            keymap = { preset = "inherit", ["<M-y>"] = false, ["<M-p>"] = false },
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
                            width = { max = 20 },
                            text = function(ctx) return ctx.kind or "" end,
                            highlight = function(ctx)
                                if ctx.kind then return "BlinkCmpKind" .. ctx.kind end
                                return "BlinkCmpKind"
                            end,
                        },
                        source_name = {
                            width = { max = 20 },
                            text = function(ctx) return "[" .. ctx.source_name .. "]" end,
                            highlight = "Comment",
                        },
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
                function(cmp) cmp.select_prev({ auto_insert = false }) end,
            },
            ["<C-n>"] = {
                function(cmp) cmp.select_next({ auto_insert = false }) end,
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

        -- PR: If the sources option is a function, and dictionary is one of the possible sources,
        -- what can happen is that the dictionary can spawn an fzf process that is not closed.
        -- The easiest way to observe this is by typing "let's" repeatedly. This issue seems to
        -- occur when the dictionary runs out of sources. Even without the dynamic source config,
        -- you can still see an fzf job spawn and take a moment to close sometimes when the
        -- dictionary runs out of words. If you type the words slowly, one character at a time,
        -- this does not occur. I cannot help but note that, yes, this is an issue that occurs
        -- because I type too fast. My vague theory is that, during the period when blink is
        -- running the function to check providers, it is not sending events to those providers,
        -- and the dictionary provider relies on an event from cmp to close the fzf job that it is
        -- not getting. But this would need testing with a minimal config to isolate
        -- I can also see this occurring if another async source is running alongside the
        -- Dictionary source, which points further to me at the broken event loop idea
        -- In the meantime, if I statically set the sources by filetype and make sure no async
        -- sources are running next to the dictionary, this does not occur
        -- Something else I notice is, if I type quickly with Obsidian completions on, I eventually
        -- get an error about how Vimscript functions cannot be used in a fast event context, but
        -- this doesn't happen if I type slowly. I guess I'm the fast event! But this points to
        -- blink's event handling also being an element of what's happening. A downside here
        -- seems to be that async needs to be turned off for all providers, or else if an async
        -- provider pushes completions first, then the others will not be seen
        -- UPDATE: While less frequent, this can still happen. Can trigger by just doing
        -- as;ldfkj spam. The solution here I think is to use vim.system instead of a plenary
        -- job, because then the calls are managed through Vim's context.
        -- If you prevent a prefix from being added if there is any special character, it works
        -- If you make Dictionary run synrhonously, it works
        -- If you prevent non-alpha characters from going into prefix, doesn't change. Feels like
        -- data is being polluted somehow. Like, something is being affected in a scope
        -- it's not meant to be. It also looks like both the plenary jobs and vim.system use
        -- uv.spawn under the hood, so I'm not sure that would actually do anything. Though with
        -- vim.system, you pass the callback handler and that handler does its work, whereas
        -- plenary has wrappers after uv.spawn to handle cleanup
        sources = {
            default = { "lsp", "snippets", "buffer", "path" },
            per_filetype = {
                lua = { inherit_defaults = true, "lazydev" },
                markdown = {
                    -- "dictionary",
                    "obsidian",
                    "obsidian_new",
                    "obsidian_tags",
                    "snippets",
                    "buffer",
                    "path",
                },
                sql = { "dadbod", "buffer", "path" },
                text = { "buffer", "path" },
                -- text = { "dictionary", "buffer", "path" },
            },
            providers = {
                buffer = {
                    enabled = true,
                    opts = {
                        get_bufnrs = function()
                            return vim.tbl_filter(
                                function(bufnr) return vim.bo[bufnr].buftype == "" end,
                                vim.api.nvim_list_bufs()
                            )
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
                -- dictionary = {
                --     -- NOTE: Do not set async for this provider, or else the fzf jobs it spawns
                --     -- might not be closed on exit. Per the docs, it should be async by default
                --     -- and non-blocking anyway
                --     module = "blink-cmp-dictionary",
                --     name = "Dict",
                --     max_items = 20,
                --     min_keyword_length = 3, -- How many two letter words do we need to look up?
                --     opts = {
                --         dictionary_files = {
                --             vim.fn.expand("~/.local/bin/words/words_alpha.txt"),
                --             vim.fn.expand(SpellFile),
                --         },
                --         get_prefix = function(ctx)
                --             local line = ctx.line:sub(1, ctx.cursor[2])
                --             local word = line:match("[a-zA-Z]+$")
                --             return word or ""
                --         end,
                --     },
                --     -- transform_items = function(_, items)
                --     --     local seen = {} --- @type boolean[]

                --     --     local out = vim.tbl_filter(function(item)
                --     --         local text = item.insertText or "" --- @type string

                --     --         if seen[text] then
                --     --             return false
                --     --         end

                --     --         seen[text] = true

                --     --         return #text > 0 and text:match("^[a-zA-Z]+$")
                --     --     end, items)

                --     --     return out
                --     -- end,
                -- },
                -- NOTE: To test, trigger LazyDev's specific completion by requiring a module
                lazydev = {
                    module = "lazydev.integrations.blink",
                    name = "LazyDev",
                    -- score_offset = 100,
                },
                lsp = { fallbacks = {} },
                path = { opts = { get_cwd = function(_) return vim.uv.cwd() end } },
                -- snippets = { async = true },
            },
        },
    })

    local groups = {
        BlinkCmpDocBorder = { link = "FloatBorder" },
        BlinkCmpMenuBorder = { link = "FloatBorder" },
        BlinkCmpSignatureHelpBorder = { link = "FloatBorder" },

        CmpItemAbbrDeprecated = { link = "Comment" },
        CmpItemAbbrMatch = { link = "IncSearch" },
        CmpItemAbbrMatchFuzzy = { link = "IncSearch" },
        CmpItemKindText = { link = "String" },
        CmpItemKindMethod = { link = "Function" },
        CmpItemKindFunction = { link = "Function" },
        CmpItemKindConstructor = { link = "Special" },
        CmpItemKindField = { link = "Normal" },
        CmpItemKindVariable = { link = "Normal" },
        CmpItemKindClass = { link = "Type" },
        CmpItemKindInterface = { link = "Type" },
        CmpItemKindModule = { link = "Type" },
        CmpItemKindProperty = { link = "Normal" },
        CmpItemKindUnit = { link = "Number" },
        CmpItemKindValue = { link = "String" },
        CmpItemKindEnum = { link = "Type" },
        CmpItemKindKeyword = { link = "Special" },
        CmpItemKindSnippet = { link = "Special" },
        CmpItemKindColor = { link = "DiagnosticWarn" },
        CmpItemKindFile = { link = "Normal" },
        CmpItemKindReference = { link = "@text.reference" },
        CmpItemKindFolder = { link = "Directory" },
        CmpItemKindEnumMember = { link = "@constant" },
        CmpItemKindConstant = { link = "@constant" },
        CmpItemKindStruct = { link = "Structure" },
        CmpItemKindEvent = { link = "@function" },
        CmpItemKindOperator = { link = "@operator" },

        BlinkCmpKindTypeParameter = { link = "Type" },
    } --- @type {string: vim.api.keyset.highlight}

    for k, v in pairs(groups) do
        vim.api.nvim_set_hl(0, k, v)
    end
end

vim.api.nvim_create_autocmd({ "CmdlineEnter", "BufReadPre", "BufNewFile" }, {
    group = vim.api.nvim_create_augroup("setup-blink", { clear = true }),
    once = true,
    callback = function()
        local path = nil --- @type string
        for _, s in pairs(vim.pack.get()) do
            if s.spec.name == "blink.cmp" then
                path = s.path
                break
            end
        end

        if not path then
            local msg = "blink.cmp path not found. Cannot build fuzzy" --- @type string
            vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, {})
            return
        end

        local cmd = { "cargo", "+nightly", "build", "--release" } --- @type string[]
        local sys_opts = { cwd = path, text = true } --- @type vim.SystemOpts
        vim.api.nvim_echo({ { "Building fuzzy for blink.cmp...", "" } }, true, {})

        vim.system(cmd, sys_opts, function(out)
            if out.code == 0 then
                vim.schedule(function()
                    -- MAYBE: Substring the stderr to get the build time. Only print if it's high
                    -- local msg = "Fuzzy built successfully. Setting up blink..." --- @type string
                    -- vim.api.nvim_echo({ { msg, "" } }, true, {})
                    vim.api.nvim_echo({ { "", "" } }, false, {})
                    setup_blink()
                end)

                return
            end

            vim.schedule(function()
                local msg = out.stderr or "Unknown error building fuzzy for blink" --- @type string
                vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
            end)
        end)

        vim.api.nvim_del_augroup_by_name("setup-blink")
    end,
})

-- NOTES:
-- There is an available keymap for viewing completion options from a specific source
-- The recipes page has info on how to disable completion for specific buf types
-- If we get too many meaningless sources in comments, the recipes page has a way to filter them

-- Source Notes:
-- https://github.com/niuiic/blink-cmp-rg.nvim -- A lot, but looks customizable
-- https://github.com/mikavilpas/blink-ripgrep.nvim -- Similar to the above
-- https://github.com/Kaiser-Yang/blink-cmp-avante -- If we go the Avante route
-- https://github.com/phanen/blink-cmp-register -- Maybe
-- https://github.com/bydlw98/blink-cmp-sshconfig -- Niche but maybe
