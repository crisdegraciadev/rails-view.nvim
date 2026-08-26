local config = require("rails-view.config")
local util = require("rails-view.util")

local M = {}

--- Lower sorts first. Templates named in template_priority keep that order,
--- any other .html.* comes next, and everything else last.
local function rank(filename, action)
  local priority = config.options.template_priority

  for index, suffix in ipairs(priority) do
    if filename == action .. "." .. suffix then
      return index
    end
  end

  if filename:match("^" .. vim.pesc(action) .. "%.html%.") then
    return #priority + 1
  end

  return #priority + 2
end

--- Every template belonging to an action, best first. An action commonly
--- has several: index.html.erb next to index.js.erb.
---@param root string
---@param controller string
---@param action string
---@return table[] { path, relative }
function M.views(root, controller, action)
  local found = {}

  for _, view_dir in ipairs(config.options.view_dirs) do
    local relative_dir = ("%s/%s"):format(view_dir, controller)
    local dir = ("%s/%s"):format(root, relative_dir)

    if vim.uv.fs_stat(dir) then
      for name, entry_type in vim.fs.dir(dir) do
        if entry_type == "file" and name:match("^" .. vim.pesc(action) .. "%.") then
          table.insert(found, {
            path = dir .. "/" .. name,
            relative = relative_dir .. "/" .. name,
            rank = rank(name, action),
          })
        end
      end
    end
  end

  table.sort(found, function(a, b)
    if a.rank ~= b.rank then
      return a.rank < b.rank
    end
    return a.relative < b.relative
  end)

  return found
end

--- The controller file, and the line its action is defined on when it is
--- defined at all: plenty of actions are inherited and never written down.
---@param root string
---@param controller string
---@param action string
---@return table|nil { path, relative, line }
function M.controller(root, controller, action)
  for _, controller_dir in ipairs(config.options.controller_dirs) do
    local relative = ("%s/%s_controller.rb"):format(controller_dir, controller)
    local path = ("%s/%s"):format(root, relative)
    local contents = util.read_file(path)

    if contents then
      local line, number = nil, 0
      for text in (contents .. "\n"):gmatch("(.-)\n") do
        number = number + 1
        if text:match("^%s*def%s+" .. vim.pesc(action) .. "%f[^%w_]") then
          line = number
          break
        end
      end

      return { path = path, relative = relative, line = line }
    end
  end
end

--- Everything a route can be opened at.
---@param root string
---@param route table
---@return table { route, views, controller }
function M.resolve(root, route)
  return {
    route = route,
    views = M.views(root, route.controller, route.action),
    controller = M.controller(root, route.controller, route.action),
  }
end

return M
