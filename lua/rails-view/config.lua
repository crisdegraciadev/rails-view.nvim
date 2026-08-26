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

  -- How many routing tables to keep per project. One per state of the route
  -- files, so this is roughly how many branches can be moved between before
  -- the oldest has to be rebuilt.
  cache_entries = 5,

  -- How a resolved file is opened: "edit", "split", "vsplit", "tabedit".
  open_cmd = "edit",

  -- "auto"   opens the best candidate straight away, and :RailsView!
  --          asks instead
  -- "always" asks whenever there is more than one candidate
  pick = "auto",

  -- Verb assumed for a URL that carries none.
  default_verb = "GET",

  -- Rebuild the routing table in the background after a route file is saved.
  auto_refresh = true,

  -- Where templates and controllers live, relative to the root.
  view_dirs = { "app/views" },
  controller_dirs = { "app/controllers" },

  -- Which template wins when an action has more than one. Compared against
  -- the end of the filename; anything else .html.* sorts just behind these.
  template_priority = {
    "html.erb",
    "html.slim",
    "html.haml",
    "turbo_stream.erb",
    "turbo_stream.slim",
    "js.erb",
    "json.jbuilder",
  },
}

M.options = vim.deepcopy(defaults)

---@param opts table|nil
---@return table
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
  return M.options
end

return M
