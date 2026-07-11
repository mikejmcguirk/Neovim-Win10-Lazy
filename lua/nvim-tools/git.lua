local api = vim.api
local fn = vim.fn
local fs = vim.fs

local M = {}

---------------------------
-- MARK: Vibe Coded POCs --
---------------------------

--- Remove the file associated with a buffer from Git.
--- Runs `git rm` (with optional --force).
---
--- @param buf integer          Buffer number (0 = current)
--- @param force? boolean       Whether to pass --force
--- @return boolean ok
--- @return string? err         Error message on failure
function M.git_rm(buf, force)
    buf = (buf == 0 or buf == nil) and api.nvim_get_current_buf() or buf

    local git_dir = M.buf_get_git_dir(buf)
    if git_dir == "" then
        return false, "Buffer is not in a git repository"
    end

    local filepath = api.nvim_buf_get_name(buf)
    if filepath == "" then
        return false, "Buffer has no associated file"
    end

    local args = { "rm" }
    if force then
        table.insert(args, "--force")
    end
    table.insert(args, "--")
    table.insert(args, filepath)

    -- cwd must be the repo root (parent of .git)
    local repo_root = fn.fnamemodify(git_dir, ":h")

    local result = vim.system({ "git", unpack(args) }, {
        cwd = repo_root,
        text = true,
    }):wait()

    if result.code == 0 then
        return true
    else
        local msg = vim.trim(result.stderr or result.stdout or "")
        return false, msg ~= "" and msg or "git rm failed"
    end
end

--- Move/rename a file tracked by git using `git mv`.
--- On success, updates the buffer to point to the new file path.
---
--- @param buf integer          Buffer number (0 or nil = current)
--- @param destination string   Destination path (relative to repo root or absolute)
--- @param force? boolean       Pass --force to git mv
--- @return boolean ok
--- @return string? err
function M.git_mv(buf, destination, force)
    buf = (buf == 0 or buf == nil) and api.nvim_get_current_buf() or buf

    local git_dir = M.buf_get_git_dir(buf)
    if git_dir == "" then
        return false, "Buffer is not in a git repository"
    end

    local src = api.nvim_buf_get_name(buf)
    if src == "" then
        return false, "Buffer has no associated file"
    end

    if not destination or destination == "" then
        return false, "No destination provided"
    end

    local args = { "mv" }
    if force then
        table.insert(args, "--force")
    end
    table.insert(args, "--")
    table.insert(args, src)
    table.insert(args, destination)

    local repo_root = fn.fnamemodify(git_dir, ":h")

    local result = vim.system({ "git", unpack(args) }, {
        cwd = repo_root,
        text = true,
    }):wait()

    if result.code ~= 0 then
        local msg = vim.trim(result.stderr or result.stdout or "")
        return false, msg ~= "" and msg or "git mv failed"
    end

    -- === Success: update buffer name ===
    local new_path
    if fn.isabsolutepath(destination) == 1 then
        new_path = destination
    else
        new_path = fs.joinpath(repo_root, destination)
    end
    new_path = fs.normalize(new_path)

    api.nvim_buf_set_name(buf, new_path)

    -- Make sure the buffer knows the file may have changed on disk
    vim.cmd("checktime")

    return true
end

-- Module caches (equivalent to s:resolved_git_dirs and s:dir_for_worktree)
---@param buf uinteger
---@return string
function M.buf_get_git_dir(buf)
    local bt = api.nvim_get_option_value("bt", { buf = buf })
    if bt ~= "" and bt ~= "help" then
        return ""
    end

    local bufdir = fs.dirname(fs.normalze(api.nvim_buf_get_name(buf)))
    if bufdir == "" then
        return ""
    end

    while bufdir ~= "" and bufdir ~= "/" do
        local bufdir_git = bufdir .. "/.git"
        if fn.isdirectory(bufdir_git) == 1 then
            return bufdir_git
        end

        local parent = fs.dirname(bufdir)
        if parent == bufdir then
            break
        end

        bufdir = parent
    end

    return ""
end

return M

-- TODO: Support callbacks so users can do something like fire autocmds
-- TODO: For any vim.fs calls, see if there's a more appropriate/direct fnamemodify call

-- DOC: Git worktrees and env variables are not supported.

-- MID: Support Git worktrees.
-- MID: Support the GIT_DIR, GIT_WORK_TREE, and GIT_CEILING_DIRECTORIES env variables.
