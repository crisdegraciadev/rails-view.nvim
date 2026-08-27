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
  local contents = util.read_file(project.cache_path(root))
  if not contents then
    vim.health.info("No routing table cached yet; the first jump builds one")
    return
  end

  local ok, decoded = pcall(vim.json.decode, contents)
  if not ok or type(decoded) ~= "table" or type(decoded.routes) ~= "table" then
    vim.health.warn("Cache file cannot be read: " .. project.cache_path(root))
    return
  end

  local built_at = decoded.built_at or 0
  local summary = ("Cache: %d routes, built %s"):format(#decoded.routes, os.date("%Y-%m-%d %H:%M", built_at))

  if project.routes_changed_at(root) > built_at then
    vim.health.warn(summary .. "; the route files have changed since", { "Run :RailsViewRefresh to rebuild it" })
  else
    vim.health.ok(summary)
  end
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
