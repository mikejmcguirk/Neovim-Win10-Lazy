local blink = require("blink.cmp")
vim.lsp.config("*", { capabilities = require("blink.cmp").get_lsp_capabilities(nil, true) })

local function is_comment()
    local ok, lang_tree = pcall(vim.treesitter.get_parser)
    if (not ok) or not lang_tree then
        if type(lang_tree) == "string" then
            vim.api.nvim_echo({ { lang_tree } }, true, { kind = "echoerr" })
        else
            vim.notify("Unknown error getting parser in is_comment", vim.log.levels.ERROR)
        end
        return false
    end
    lang_tree:parse()

    -- Include col before or a cursor at the very end of a comment will be a "chunk" node
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local start_col = col > 0 and col - 1 or col
    local node = lang_tree:node_for_range({ row - 1, start_col, row - 1, col })
    if not node then
        return false
    end

    local comment_nodes = { "comment", "line_comment", "block_comment", "comment_content" }
    if vim.tbl_contains(comment_nodes, node:type()) then
        return true
    else
        return false
    end
end

local function setup_blink()
    blink.setup({
        completion = {
            accept = { auto_brackets = { enabled = true } },
            documentation = {
                auto_show = true,
                auto_show_delay_ms = 100,
                window = { border = "single" },
            },
            menu = {
                border = "single",
                draw = {
                    columns = { { "label" }, { "kind" }, { "source_name" } },
                    components = {
                        kind = {
                            width = { max = 20 },
                            text = function(ctx)
                                return ctx.kind or ""
                            end,
                            highlight = function(ctx)
                                if ctx.kind then
                                    return "CmpItemKind" .. ctx.kind
                                end
                                return "CmpItemKindField"
                            end,
                        },
                        source_name = {
                            width = { max = 20 },
                            text = function(ctx)
                                return "[" .. ctx.source_name .. "]"
                            end,
                            highlight = "Comment",
                        },
                    },
                },
            },
        },
        fuzzy = { sorts = { "exact", "score", "sort_text" } },
        keymap = {
            preset = "none",
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
            default = function()
                local s = { "buffer", "path" }

                local ft = vim.api.nvim_get_option_value("filetype", { buf = 0 })
                if ft == "lua" then
                    table.insert(s, "lazydev")
                end

                local is_prose = vim.tbl_contains({ "text", "markdown" }, ft)
                local in_comment = is_comment()
                if is_prose or in_comment then
                    table.insert(s, "dictionary")
                else
                    table.insert(s, "snippets")
                    if ft ~= "sql" then
                        table.insert(s, "lsp")
                        return s
                    end
                end

                if ft == "sql" then
                    table.insert(s, "dadbod")
                end

                if ft == "markdown" then
                    table.insert(s, "obsidian")
                    table.insert(s, "obsidian_new")
                    table.insert(s, "obsidian_tags")
                end

                return s
            end,
            providers = {
                buffer = {
                    async = true,
                    enabled = true,
                    opts = {
                        get_bufnrs = function()
                            return vim.tbl_filter(function(bufnr)
                                return vim.bo[bufnr].buftype == ""
                            end, vim.api.nvim_list_bufs())
                        end,
                    },
                    score_offset = -6,
                    transform_items = function(a, items)
                        local prose_ft = { "text", "markdown" }
                        local ft = vim.api.nvim_get_option_value("filetype", { buf = 0 })
                        if not (vim.tbl_contains(prose_ft, ft) or is_comment()) then
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
                dictionary = {
                    async = true,
                    module = "blink-cmp-dictionary",
                    name = "Dict",
                    min_keyword_length = 2, -- Try 3 if this is slow
                    opts = {
                        -- Note: This can be a function that returns a table as well
                        dictionary_files = {
                            vim.fn.expand("~/.local/bin/words/words_alpha.txt"),
                            vim.fn.expand(SpellFile),
                        },
                        -- dictionary_directories = nil
                    },
                    transform_items = function(a, items)
                        local f = vim.tbl_filter(function(item)
                            local text = item.insertText or ""
                            return #text > 0 and text:match("^[a-zA-Z]+$") ~= nil
                        end, items)

                        local keyword = a.get_keyword()
                        local correct, case
                        if keyword:match("^%l") then
                            correct = "^%u%l+$"
                            case = string.lower
                        elseif keyword:match("^%u") then
                            correct = "^%l+$"
                            case = string.upper
                        else
                            return f
                        end

                        local seen = {}
                        local out = {}
                        for _, item in ipairs(f) do
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
                lazydev = {
                    async = true,
                    module = "lazydev.integrations.blink",
                    name = "LazyDev",
                    score_offset = 100,
                },
                lsp = { async = true, fallbacks = {} },
                obsidian = {
                    async = true,
                    name = "obsidian",
                    module = "blink.compat.source",
                    score_offset = 2,
                    -- opts = require("cmp_obsidian").new()
                },
                obsidian_new = {
                    async = true,
                    name = "obsidian_new",
                    module = "blink.compat.source",
                    score_offset = 3,
                    -- opts = require("cmp_obsidian_new").new()
                },
                obsidian_tags = {
                    async = true,
                    name = "obsidian_tags",
                    module = "blink.compat.source",
                    -- opts = require("cmp_obsidian_tags").new()
                },
                path = {
                    async = true,
                    opts = {
                        get_cwd = function(_)
                            return vim.fn.getcwd()
                        end,
                    },
                },
                snippets = { async = true },
            },
        },
    })

    local win_border = vim.api.nvim_get_hl(0, { name = "FloatBorder" })
    -- PR: The fact I have to suppress these diagnostics feels like an issue
    --- @diagnostic disable: param-type-mismatch
    vim.api.nvim_set_hl(0, "BlinkCmpMenuBorder", win_border)
    vim.api.nvim_set_hl(0, "BlinkCmpDocBorder", win_border)
    vim.api.nvim_set_hl(0, "BlinkCmpSignatureHelpBorder", win_border)
end

vim.api.nvim_create_autocmd("InsertEnter", {
    group = vim.api.nvim_create_augroup("setup-blink", { clear = true }),
    once = true,
    callback = function()
        setup_blink()
        --- @diagnostic disable: missing-parameter
        require("blink-compat").setup()
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
