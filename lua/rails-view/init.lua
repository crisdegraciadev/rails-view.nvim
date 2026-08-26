local config = require("rails-view.config")
local matcher = require("rails-view.matcher")
local project = require("rails-view.project")
local resolver = require("rails-view.resolver")
local routes = require("rails-view.routes")
local url = require("rails-view.url")
local util = require("rails-view.util")

local M = {}

M.setup = config.setup

local function open_file(path, opts)
  vim.cmd(("%s %s"):format(opts.open_cmd or config.options.open_cmd, vim.fn.fnameescape(path)))

  if opts.line then
    pcall(vim.api.nvim_win_set_cursor, 0, { opts.line, 0 })
    vim.cmd("normal! zz")
  end
end

local function route_label(route)
  local verb = (route.verb ~= nil and route.verb ~= "") and route.verb or "ANY"
  return ("%-6s %s  ->  %s#%s"):format(verb, route.uri, route.controller, route.action)
end

--- What a resolved route can be opened at, best first.
---@param resolved table
---@param target string "view" | "controller" | "any"
---@return table[] { label, path, line }
local function candidates(resolved, target)
  local items = {}

  if target ~= "controller" then
    for _, view in ipairs(resolved.views) do
      table.insert(items, { label = view.relative, path = view.path })
    end
  end

  -- The controller is the answer for "controller" and "any", and the
  -- fallback when an action renders no template of its own.
  local wants_controller = target == "controller" or target == "any" or #items == 0
  if resolved.controller and wants_controller then
    local line = resolved.controller.line
    table.insert(items, {
      label = resolved.controller.relative .. (line and (":" .. line) or ""),
      path = resolved.controller.path,
      line = line,
    })
  end

  return items
end

local function open_route(root, route, opts)
  local resolved = resolver.resolve(root, route)
  local items = candidates(resolved, opts.target)

  if #items == 0 then
    util.warn(("%s -> %s#%s\nNo template under %s/%s/ and no %s/%s_controller.rb"):format(
      route.uri,
      route.controller,
      route.action,
      config.options.view_dirs[1],
      route.controller,
      config.options.controller_dirs[1],
      route.controller
    ))
    return
  end

  if #items == 1 or (config.options.pick == "auto" and not opts.pick) then
    open_file(items[1].path, { open_cmd = opts.open_cmd, line = items[1].line })
    return
  end

  vim.ui.select(items, {
    prompt = ("%s#%s"):format(route.controller, route.action),
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    if choice then
      open_file(choice.path, { open_cmd = opts.open_cmd, line = choice.line })
    end
  end)
end

--- Resolves a request against the project and hands the routes to `handler`.
--- Everything that can go wrong before that point is reported here.
---@param input string
---@param handler fun(root: string, matched: table[], request: table)
local function with_matching_routes(input, handler)
  local root = project.root()
  if not root then
    util.error("No Rails project found from here: no config/routes.rb up the tree")
    return
  end

  local request, err = url.parse(input, config.options.default_verb)
  if not request then
    util.error(err)
    return
  end

  routes.get(root, function(all, routes_err)
    if not all then
      util.error(routes_err)
      return
    end

    local exact, path_only = matcher.find(all, request.path, request.verb)

    if #exact == 0 and #path_only == 0 then
      util.warn(("No route matches %s %s"):format(request.verb, request.path))
      return
    end

    if #exact == 0 then
      util.notify(("%s has no %s route, using %s"):format(request.path, request.verb, path_only[1].verb))
      exact = path_only
    end

    handler(root, exact, request)
  end)
end

--- Opens the file behind a URL.
---@param input string
---@param opts table|nil { target = "view"|"controller"|"any", pick = boolean, open_cmd = string }
function M.open(input, opts)
  opts = vim.tbl_extend("force", { target = "view", pick = false }, opts or {})

  with_matching_routes(input, function(root, matched, request)
    if #matched > 1 and (opts.pick or config.options.pick == "always") then
      vim.ui.select(matched, {
        prompt = ("%s %s"):format(request.verb, request.path),
        format_item = route_label,
      }, function(choice)
        if choice then
          open_route(root, choice, opts)
        end
      end)
      return
    end

    -- Definition order is Rails' precedence: the first match is the one the
    -- running application would serve.
    open_route(root, matched[1], opts)
  end)
end

--- Reports what a URL resolves to without opening anything.
---@param input string
function M.info(input)
  with_matching_routes(input, function(root, matched, request)
    local lines = { ("%s %s"):format(request.verb, request.path), "" }

    for index, route in ipairs(matched) do
      local resolved = resolver.resolve(root, route)
      table.insert(lines, ("%d. %s"):format(index, route_label(route)))

      if route.prefix then
        table.insert(lines, ("     helper: %s_path"):format(route.prefix))
      end
      if route.source_file then
        table.insert(lines, ("     route:  %s:%s"):format(route.source_file, route.source_line or "?"))
      end

      if #resolved.views == 0 then
        table.insert(lines, "     view:   none")
      end
      for _, view in ipairs(resolved.views) do
        table.insert(lines, "     view:   " .. view.relative)
      end

      if resolved.controller then
        local line = resolved.controller.line
        table.insert(lines, ("     ctrl:   %s%s"):format(resolved.controller.relative, line and (":" .. line) or ""))
      end
    end

    util.notify(table.concat(lines, "\n"))
  end)
end

--- Rebuilds the routing table, whatever the cache says.
function M.refresh()
  local root = project.root()
  if not root then
    util.error("No Rails project found from here: no config/routes.rb up the tree")
    return
  end

  routes.invalidate(root)
  routes.refresh(root, function(_, err)
    if err then
      util.error(err)
    end
  end)
end

--- A URL to offer as the default when the user is asked for one: the word
--- under the cursor, else whatever was copied last.
---@return string
function M.guess_url()
  local under_cursor = vim.fn.expand("<cWORD>")
  if url.looks_like_url(under_cursor) then
    return vim.trim(under_cursor)
  end

  for _, register in ipairs({ "+", "*", '"' }) do
    local ok, contents = pcall(vim.fn.getreg, register)
    if ok and url.looks_like_url(contents) then
      return vim.trim(contents)
    end
  end

  return ""
end

--- Opens `input`, asking for a URL when the command was given none.
---@param input string|nil
---@param opts table|nil
function M.open_or_prompt(input, opts)
  if input and vim.trim(input) ~= "" then
    M.open(input, opts)
    return
  end

  vim.ui.input({ prompt = "URL: ", default = M.guess_url() }, function(value)
    if value and vim.trim(value) ~= "" then
      M.open(value, opts)
    end
  end)
end

return M
