local M = {}

------------------
--- Highlights ---
------------------

local function darken_24bit(color, pct)
    local r = bit.band(bit.rshift(color, 16), 0xFF)
    local g = bit.band(bit.rshift(color, 8), 0xFF)
    local b = bit.band(color, 0xFF)

    r = math.max(0, math.floor(r * (1 - pct / 100)))
    g = math.max(0, math.floor(g * (1 - pct / 100)))
    b = math.max(0, math.floor(b * (1 - pct / 100)))

    return bit.bor(bit.lshift(r, 16), bit.lshift(g, 8), b)
end

local fg = vim.api.nvim_get_hl(0, { name = "Normal" }).fg
local bg = vim.api.nvim_get_hl(0, { name = "ColorColumn" }).bg
local hl_modes = {
    norm = vim.api.nvim_get_hl(0, { name = "String" }).fg,
    ins = vim.api.nvim_get_hl(0, { name = "Identifier" }).fg,
    vis = vim.api.nvim_get_hl(0, { name = "Boolean" }).fg,
    rep = vim.api.nvim_get_hl(0, { name = "Constant" }).fg,
    cmd = vim.api.nvim_get_hl(0, { name = "CurSearch" }).bg,
}
local prefix = "mjm-status-"

for m, m_fg in pairs(hl_modes) do
    local a = string.format("%s%s", m, "-a")
    local group_a = string.format("%s%s", prefix, a)
    vim.api.nvim_set_hl(0, group_a, { fg = m_fg, bg = bg })
    M[a] = group_a

    local b = string.format("%s%s", m, "-b")
    local b_bg = darken_24bit(m_fg, 50)
    local group_b = string.format("%s%s", prefix, b)
    vim.api.nvim_set_hl(0, group_b, { fg = m_fg, bg = b_bg })
    M[b] = group_b

    local c = string.format("%s%s", m, "-c")
    local group_c = string.format("%s%s", prefix, c)
    vim.api.nvim_set_hl(0, group_c, { fg = fg, bg = bg })
    M[c] = group_c
end

-------------
--- Modes ---
-------------

-- Cribbed from LuaLine
M.modes = {
    ["n"] = "norm",
    ["no"] = "norm",
    ["nov"] = "norm",
    ["noV"] = "norm",
    ["no\22"] = "norm",
    ["niI"] = "norm",
    ["niR"] = "norm",
    ["niV"] = "norm",
    ["nt"] = "norm",
    ["ntT"] = "norm",
    ["v"] = "vis",
    ["vs"] = "vis",
    ["V"] = "vis",
    ["Vs"] = "vis",
    ["\22"] = "vis",
    ["\22s"] = "vis",
    ["s"] = "vis",
    ["S"] = "vis",
    ["\19"] = "vis",
    ["i"] = "ins",
    ["ic"] = "ins",
    ["ix"] = "ins",
    ["R"] = "rep",
    ["Rc"] = "rep",
    ["Rx"] = "rep",
    ["Rv"] = "vis",
    ["Rvc"] = "vis",
    ["Rvx"] = "vis",
    ["c"] = "cmd",
    ["cv"] = "cmd",
    ["ce"] = "cmd",
    ["r"] = "rep",
    ["rm"] = "cmd",
    ["r?"] = "cmd",
    -- Didn't see an explicit mapping for these in lualine'
    ["!"] = "norm",
    ["t"] = "norm",
}

----------------------
--- Git Dir/Status ---
----------------------

local function find_git_dir_async(callback)
    local function search(dir)
        if not dir or dir == "/" then
            return callback(nil)
        end

        local git_path = vim.fs.joinpath(dir, ".git") --- @type string
        vim.uv.fs_stat(git_path, function(err, stat)
            if err or not stat then
                local parent = vim.fs.dirname(dir) --- @type string|nil
                if parent == dir then
                    return callback(nil)
                end

                return search(parent)
            end

            if stat.type == "directory" then
                return callback(git_path)
            elseif stat.type ~= "file" then
                return callback(nil)
            end

            --- @param err_open string|nil
            --- @param fd integer
            vim.uv.fs_open(git_path, "r", 438, function(err_open, fd)
                if err_open or not fd then
                    return callback(nil)
                end

                vim.uv.fs_fstat(
                    fd,
                    function(err_fstat, fstat) --- @type string|nil, uv.fs_stat.result|nil
                        if err_fstat or not fstat then
                            vim.uv.fs_close(fd, function() end)

                            return callback(nil)
                        end

                        vim.uv.fs_read(
                            fd,
                            fstat.size,
                            0,
                            function(err_read, content) --- @type string|nil, string
                                vim.uv.fs_close(fd, function() end)
                                if err_read or not content then
                                    return callback(nil)
                                end

                                --- @type string|nil
                                local git_dir = content:match("gitdir:%s*(.-)%s*$")
                                if not git_dir then
                                    return callback(nil)
                                end

                                if not vim.startswith(git_dir, "/") then
                                    --- @type string
                                    git_dir = vim.fs.normalize(vim.fs.joinpath(dir, git_dir))
                                end

                                local head_path = vim.fs.joinpath(git_dir, "HEAD") --- @type string
                                vim.uv.fs_stat(
                                    head_path,
                                    --- @type string|nil, uv.fs_stat.result|nil
                                    function(err_head, stat_head)
                                        if err_head or not stat_head then
                                            return callback(nil)
                                        end

                                        return callback(git_dir)
                                    end
                                )
                            end
                        )
                    end
                )
            end)
        end)
    end

    search(vim.uv.cwd())
end

function M.check_head()
    -- NOTE: Don't require at module scope. Since this module is required by stl, causes a loop
    local stl = require("mjm.stl")
    if not M.git_root then
        return
    end

    local head_cmd = { "git", "--git-dir=" .. M.git_root, "rev-parse", "--abbrev-ref", "HEAD" }
    vim.system(
        head_cmd,
        { text = true },
        vim.schedule_wrap(function(out)
            if out.code ~= 0 then
                return
            end

            local head = vim.trim(out.stdout)
            if head:match("^fatal:") then
                M.head = nil
                return
            end

            M.head = head
            stl.event_router({ event = "mjmGitHeadFound" })
        end)
    )
end

local function send_nogit()
    require("mjm.stl").event_router({ event = "mjmNoGit" })
end

function M.setup_stl_git_dir()
    find_git_dir_async(function(git_dir)
        if git_dir then
            M.git_root = git_dir
            M.check_head()
            return
        end

        local had_git = M.git_root
        M.git_root = nil
        M.head = nil
        if had_git then
            vim.schedule(send_nogit) -- Leave fast event context
        end
    end)
end

--------------------
--- LSP Progress ---
--------------------

M.progress = nil --- @type {client_id:integer, params:lsp.ProgressParams, msg: string}

-------------------
--- Diagnostics ---
-------------------

M.diag_cache = {}

function M.process_diags(opts)
    opts = opts or {}
    local buf = opts.buf or vim.api.nvim_get_current_buf()

    local raw_diags = opts.diags or vim.diagnostic.get(buf)
    local counts = vim.iter(raw_diags)
        :filter(function(d)
            return d.bufnr == buf
        end)
        :fold({
            ERROR = 0,
            WARN = 0,
            HINT = 0,
            INFO = 0,
        }, function(acc, d)
            local severity = vim.diagnostic.severity[d.severity]
            acc[severity] = acc[severity] + 1
            return acc
        end)

    M.diag_cache[tostring(buf)] = counts
end

function M.cache_diags(buf, diags)
    local counts = vim.iter(diags)
        :filter(function(d)
            return d.bufnr == buf
        end)
        :fold({
            ERROR = 0,
            WARN = 0,
            HINT = 0,
            INFO = 0,
        }, function(acc, d)
            local severity = vim.diagnostic.severity[d.severity]
            acc[severity] = acc[severity] + 1
            return acc
        end)

    M.diag_cache[tostring(buf)] = counts
end

----------------
--- Scroll % ---
----------------

function M.get_scroll_pct(opts)
    opts = opts or {}
    local win = opts.win or vim.api.nvim_get_current_win()
    local row = vim.api.nvim_win_get_cursor(win)[1]
    local tot_rows = vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(win))

    if row == tot_rows then
        return 100
    end

    local pct = math.floor(row / tot_rows * 100)
    pct = math.min(pct, 99)
    pct = math.max(pct, 1)
    return pct
end

return M
