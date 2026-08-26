local project = require("rails-view.project")
local util = require("rails-view.util")

local M = {}

-- root -> { fingerprint = string, routes = table[] }
local memory = {}

--- Reads the output of `rails routes --expanded`, which prints one block
--- per route:
---
---   --[ Route 431 ]------------------------------------
---   Prefix            | company_jobs
---   Verb              | GET
---   URI               | /companies/:company_id/jobs(.:format)
---   Controller#Action | companies/jobs#index
---   Source Location   | config/routes.rb:553
---
---@param output string
---@return table[] routes in definition order
function M.parse(output)
  local routes = {}
  local current

  local function flush()
    if current and current.uri and current.controller then
      current.order = #routes + 1
      table.insert(routes, current)
    end
    current = nil
  end

  for line in (output .. "\n"):gmatch("(.-)\n") do
    if line:match("^%-%-%[%s*Route") then
      flush()
      current = {}
    elseif current then
      local key, value = line:match("^([^|]*)|(.*)$")
      if key then
        key, value = vim.trim(key), vim.trim(value)

        if key == "Prefix" then
          current.prefix = value ~= "" and value or nil
        elseif key == "Verb" then
          current.verb = value
        elseif key == "URI" then
          current.uri = value
        elseif key == "Controller#Action" then
          -- Mounted engines print an inspected object here rather than a
          -- controller, and constraints are appended to the real ones:
          --   api/v3/sessions#create {format: :json}
          local pair = value:match("^([%w_/]+#[%w_?!]+)")
          if pair then
            current.controller, current.action = pair:match("^(.+)#(.+)$")
          end
        elseif key == "Source Location" then
          local file, line_number = value:match("^(.*):(%d+)$")
          current.source_file = file
          current.source_line = tonumber(line_number)
        end
      end
    end
  end
  flush()

  return routes
end

--- Returns the cached routing table, or nil when there is none for the
--- current state of the route files.
---@param root string
---@return table[]|nil
function M.load_cache(root)
  local fingerprint = project.fingerprint(root)

  local cached = memory[root]
  if cached and cached.fingerprint == fingerprint then
    return cached.routes
  end

  local contents = util.read_file(project.cache_path(root))
  if not contents then
    return nil
  end

  local ok, decoded = pcall(vim.json.decode, contents)
  if not ok or type(decoded) ~= "table" or type(decoded.routes) ~= "table" then
    return nil
  end
  if decoded.fingerprint ~= fingerprint then
    return nil
  end

  memory[root] = { fingerprint = fingerprint, routes = decoded.routes }
  return decoded.routes
end

---@param root string
---@param routes table[]
function M.save_cache(root, routes)
  local fingerprint = project.fingerprint(root)
  memory[root] = { fingerprint = fingerprint, routes = routes }

  -- Compiled patterns are per-session state, not data worth storing.
  local plain = vim.tbl_map(function(route)
    local copy = vim.deepcopy(route)
    copy.patterns = nil
    return copy
  end, routes)

  util.write_file(
    project.cache_path(root),
    vim.json.encode({ fingerprint = fingerprint, routes = plain })
  )
end

--- Drops the cache for a project, in memory and on disk.
---@param root string
function M.invalidate(root)
  memory[root] = nil
  os.remove(project.cache_path(root))
end

return M
