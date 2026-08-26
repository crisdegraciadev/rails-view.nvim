local config = require("rails-view.config")
local project = require("rails-view.project")
local util = require("rails-view.util")

local M = {}

local function check_routes_cmd(root)
  local cmd = config.options.routes_cmd
  local executable = cmd[1]
  local in_project = root .. "/" .. executable

  if vim.fn.executable(executable) == 1 or vim.uv.fs_stat(in_project) then
    vim.health.ok("Routes command: " .. table.concat(cmd, " "))
  else
    vim.health.error(("Cannot run `%s`"):format(executable), {
      "Set routes_cmd to whatever runs Rails here, for example:",
      '{ "docker", "compose", "exec", "-T", "web", "bin/rails", "routes", "--expanded" }',
    })
  end
end

local function check_cache(root)
  local files = project.cache_files(root)
  if #files == 0 then
    vim.health.info("No routing table cached yet; the first jump builds one")
    return
  end

  local current = project.cache_path(root, project.fingerprint(root))
  local summary = ("Cache: %d of %d routing tables in %s")
    :format(#files, config.options.cache_entries, config.options.cache_dir)

  if not vim.uv.fs_stat(current) then
    vim.health.warn(summary .. ", none for the current route files; the next jump rebuilds")
    return
  end

  local contents = util.read_file(current)
  local ok, decoded = pcall(vim.json.decode, contents or "")
  if not ok or type(decoded) ~= "table" or type(decoded.routes) ~= "table" then
    vim.health.warn("Cache file cannot be read: " .. current)
    return
  end

  vim.health.ok(("%s; the current one holds %d routes"):format(summary, #decoded.routes))
end

function M.check()
  vim.health.start("rails-view")

  if vim.fn.has("nvim-0.10") == 1 then
    vim.health.ok("Neovim 0.10 or newer")
  else
    vim.health.error("Neovim 0.10 or newer is required for vim.system and vim.uv")
  end

  local root = project.root()
  if not root then
    vim.health.warn("No Rails project found from the current buffer or the working directory")
    return
  end
  vim.health.ok("Project root: " .. root)

  check_routes_cmd(root)
  check_cache(root)
end

return M
