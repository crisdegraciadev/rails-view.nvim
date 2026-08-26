local config = require("rails-view.config")
local project = require("rails-view.project")
local util = require("rails-view.util")

local M = {}

-- "<root>\0<fingerprint>" -> routes, so several branches can be held at once
local memory = {}

-- root -> callbacks waiting on the build already in flight
local pending = {}

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

local function memory_key(root, fingerprint)
  return root .. "\0" .. fingerprint
end

--- Drops the least recently used tables beyond cache_entries.
local function prune(root)
  local files = project.cache_files(root)

  for index = config.options.cache_entries + 1, #files do
    os.remove(files[index])
  end
end

--- Returns the cached routing table for the current state of the route
--- files, or nil when it has not been built yet.
---@param root string
---@return table[]|nil
function M.load_cache(root)
  local fingerprint = project.fingerprint(root)
  local key = memory_key(root, fingerprint)

  if memory[key] then
    return memory[key]
  end

  local path = project.cache_path(root, fingerprint)
  local contents = util.read_file(path)
  if not contents then
    return nil
  end

  local ok, decoded = pcall(vim.json.decode, contents)
  if not ok or type(decoded) ~= "table" or type(decoded.routes) ~= "table" then
    return nil
  end
  if decoded.fingerprint ~= fingerprint then
    return nil -- a slug collision; the file belongs to another project
  end

  -- Reading counts as use: pruning goes by how recently a table was wanted,
  -- not by when it happened to be built.
  local now = os.time()
  vim.uv.fs_utime(path, now, now)

  memory[key] = decoded.routes
  return decoded.routes
end

---@param root string
---@param routes table[]
function M.save_cache(root, routes)
  local fingerprint = project.fingerprint(root)
  memory[memory_key(root, fingerprint)] = routes

  -- Compiled patterns are per-session state, not data worth storing.
  local plain = vim.tbl_map(function(route)
    local copy = vim.deepcopy(route)
    copy.patterns = nil
    return copy
  end, routes)

  util.write_file(
    project.cache_path(root, fingerprint),
    vim.json.encode({ fingerprint = fingerprint, routes = plain })
  )

  prune(root)
end

--- Runs the routes command and caches what it prints.
---
--- Callers arriving while a build is in flight wait on that one instead of
--- booting Rails a second time.
---@param root string
---@param callback fun(routes: table[]|nil, err: string|nil)
function M.refresh(root, callback)
  if pending[root] then
    table.insert(pending[root], callback)
    return
  end
  pending[root] = { callback }

  local function finish(routes, err)
    local waiting = pending[root]
    pending[root] = nil
    for _, waiter in ipairs(waiting) do
      waiter(routes, err)
    end
  end

  local cmd = config.options.routes_cmd
  util.notify(("Building the routing table with `%s`..."):format(table.concat(cmd, " ")))

  vim.system(cmd, { cwd = root, text = true, timeout = config.options.routes_timeout }, function(result)
    -- vim.system calls back off the main loop, where the editor API is off limits.
    vim.schedule(function()
      if result.code ~= 0 then
        local stderr = vim.trim(result.stderr or "")
        finish(
          nil,
          ("`%s` exited with %d%s"):format(
            table.concat(cmd, " "),
            result.code,
            stderr ~= "" and ("\n" .. stderr:sub(1, 500)) or ""
          )
        )
        return
      end

      local routes = M.parse(result.stdout or "")
      if #routes == 0 then
        finish(nil, ("`%s` printed no routes this plugin could read"):format(table.concat(cmd, " ")))
        return
      end

      M.save_cache(root, routes)
      util.notify(("%d routes cached"):format(#routes))
      finish(routes, nil)
    end)
  end)
end

--- The routing table for a project, from cache while it is still valid.
--- The only entry point the rest of the plugin needs.
---@param root string
---@param callback fun(routes: table[]|nil, err: string|nil)
function M.get(root, callback)
  local cached = M.load_cache(root)
  if cached then
    callback(cached, nil)
    return
  end

  M.refresh(root, callback)
end

--- Drops every cached routing table for a project, in memory and on disk.
---@param root string
function M.invalidate(root)
  local prefix = root .. "\0"
  for key in pairs(memory) do
    if key:sub(1, #prefix) == prefix then
      memory[key] = nil
    end
  end

  for _, file in ipairs(project.cache_files(root)) do
    os.remove(file)
  end
end

return M
