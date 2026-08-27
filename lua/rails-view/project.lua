local config = require("rails-view.config")

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

--- The most recent change to any route file, as a unix timestamp. Used to
--- tell whether a cached routing table predates the routes it describes.
---@param root string
---@return number
function M.routes_changed_at(root)
  local latest = 0

  for _, file in ipairs(M.route_files(root)) do
    local stat = vim.uv.fs_stat(file)
    if stat and stat.mtime.sec > latest then
      latest = stat.mtime.sec
    end
  end

  return latest
end

--- One cached routing table per project, named after its path.
---@param root string
---@return string
function M.cache_path(root)
  local slug = root:gsub("[^%w]", "_"):gsub("^_+", "")
  return ("%s/%s.json"):format(config.options.cache_dir, slug)
end

return M
