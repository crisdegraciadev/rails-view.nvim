local M = {}

local defaults = {
  -- Rails project root. Left unset, it is detected from the current buffer
  -- or the working directory.
  root = nil,

  -- Command that dumps the routing table, run with cwd set to the root.
  -- Rails in a container needs something like:
  --   { "docker", "compose", "exec", "-T", "web", "bin/rails", "routes", "--expanded" }
  routes_cmd = { "bin/rails", "routes", "--expanded" },

  -- Generous on purpose: the command boots the whole application.
  routes_timeout = 180000,

  cache_dir = vim.fn.stdpath("cache") .. "/rails-view",

  -- Verb assumed for a URL that carries none.
  default_verb = "GET",
}

M.options = vim.deepcopy(defaults)

---@param opts table|nil
---@return table
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
  return M.options
end

return M
