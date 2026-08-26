local config = require("rails-view.config")
local util = require("rails-view.util")

local M = {}

local function is_file(path)
  local stat = vim.uv.fs_stat(path)
  return stat ~= nil and stat.type == "file"
end

--- Walks up from `start` looking for config/routes.rb.
---@param start string|nil
---@return string|nil
local function find_upwards(start)
  local dir = vim.fs.normalize(start ~= nil and start ~= "" and start or vim.fn.getcwd())

  while dir ~= "" do
    if is_file(dir .. "/config/routes.rb") then
      return dir
    end

    local parent = vim.fs.dirname(dir)
    if parent == dir then
      return nil
    end
    dir = parent
  end
end

--- The Rails project to work against: the configured root, else the project
--- holding the current buffer, else the one holding the working directory.
--- The buffer comes first so a split into another project still resolves
--- against that project.
---@return string|nil
function M.root()
  if config.options.root then
    return vim.fs.normalize(config.options.root)
  end

  local bufname = vim.api.nvim_buf_get_name(0)
  if bufname ~= "" then
    local from_buffer = find_upwards(vim.fs.dirname(bufname))
    if from_buffer then
      return from_buffer
    end
  end

  return find_upwards(vim.fn.getcwd())
end

--- Every file that can change the routing table.
---@param root string
---@return string[]
function M.route_files(root)
  local files = {}

  if is_file(root .. "/config/routes.rb") then
    table.insert(files, root .. "/config/routes.rb")
  end
  vim.list_extend(files, vim.fn.glob(root .. "/config/routes/**/*.rb", true, true))

  table.sort(files)
  return files
end

-- path -> { stamp, sha }. Hashing a large routes.rb is not free and the
-- fingerprint is taken on every lookup, so the file is only read again once
-- its size or timestamp moves.
local hashes = {}

--- Nanoseconds matter here: two writes within the same second, of the same
--- size, are exactly what a run of git commands produces.
local function stamp(stat)
  return ("%d:%d:%d"):format(stat.size, stat.mtime.sec, stat.mtime.nsec)
end

local function file_hash(path)
  local stat = vim.uv.fs_stat(path)
  if not stat then
    return ""
  end

  local cached = hashes[path]
  if cached and cached.stamp == stamp(stat) then
    return cached.sha
  end

  local sha = vim.fn.sha256(util.read_file(path) or "")
  hashes[path] = { stamp = stamp(stat), sha = sha }
  return sha
end

--- Identifies the routing table the route files describe.
---
--- This follows their contents, not their timestamps: git rewrites these
--- files on every checkout and rebase, and rebuilding a routing table that
--- has not actually changed costs a full Rails boot.
---@param root string
---@return string
function M.fingerprint(root)
  local parts = {}

  for _, file in ipairs(M.route_files(root)) do
    -- The path is part of the fingerprint so that adding or removing a route
    -- file registers even when the remaining contents are unchanged.
    table.insert(parts, file:sub(#root + 2))
    table.insert(parts, file_hash(file))
  end

  return vim.fn.sha256(table.concat(parts, "\n"))
end

local function cache_prefix(root)
  local slug = root:gsub("[^%w]", "_"):gsub("^_+", "")
  return config.options.cache_dir .. "/" .. slug
end

--- Where the routing table for this exact state of the route files lives.
--- Keying the file by fingerprint rather than overwriting one file per
--- project means moving between branches reuses what was already built.
---@param root string
---@param fingerprint string
---@return string
function M.cache_path(root, fingerprint)
  return ("%s-%s.json"):format(cache_prefix(root), fingerprint:sub(1, 12))
end

--- Every cached routing table for a project, most recently used first.
---@param root string
---@return string[]
function M.cache_files(root)
  local files = vim.fn.glob(cache_prefix(root) .. "*.json", true, true)

  local mtimes = {}
  for _, file in ipairs(files) do
    local stat = vim.uv.fs_stat(file)
    mtimes[file] = stat and stat.mtime.sec or 0
  end

  table.sort(files, function(a, b)
    return mtimes[a] > mtimes[b]
  end)

  return files
end

return M
