local M = {}

-- A URI with more optional groups than this is pathological; matching it
-- exactly is not worth 2^n patterns.
local MAX_VARIANTS = 64

local MAGIC = "[%^%$%(%)%%%.%[%]%*%+%-%?]"

local function escape(literal)
  return (literal:gsub(MAGIC, "%%%1"))
end

local function closing_paren(str, open)
  local depth = 0
  for index = open, #str do
    local char = str:sub(index, index)
    if char == "(" then
      depth = depth + 1
    elseif char == ")" then
      depth = depth - 1
      if depth == 0 then
        return index
      end
    end
  end
end

--- Rewrites the optional groups Rails writes in parentheses as a list of
--- flat URIs, one per combination:
---
---   /posts(/:id)(.:format)
---     /posts/:id.:format  /posts/:id  /posts.:format  /posts
---
--- Lua patterns have no optional groups, so the alternative would be to
--- match each URI several times with hand-rolled rules. Expanding turns it
--- back into plain string matching.
---@param uri string
---@return string[]
function M.expand_optionals(uri)
  local open = uri:find("%(")
  if not open then
    return { uri }
  end

  local close = closing_paren(uri, open)
  if not close then
    return { uri }
  end

  local before = uri:sub(1, open - 1)
  local inner = uri:sub(open + 1, close - 1)
  local after = uri:sub(close + 1)

  local variants = {}
  for _, variant in ipairs({ before .. inner .. after, before .. after }) do
    for _, expanded in ipairs(M.expand_optionals(variant)) do
      table.insert(variants, expanded)
      if #variants >= MAX_VARIANTS then
        return variants
      end
    end
  end
  return variants
end

--- Compiles one flat URI into an anchored Lua pattern. `:param` takes a
--- single segment, `*glob` takes the rest of the path, and everything else
--- is a literal.
---@param uri string
---@return string
function M.to_lua_pattern(uri)
  local out = { "^" }
  local index = 1

  while index <= #uri do
    local char = uri:sub(index, index)

    if char == ":" or char == "*" then
      local name = uri:match(char == ":" and "^:([%w_]+)" or "^%*([%w_]+)", index)
      if name then
        table.insert(out, char == ":" and "([^/]+)" or "(.+)")
        index = index + #name + 1
      else
        table.insert(out, escape(char))
        index = index + 1
      end
    else
      local next_param = uri:find("[:%*]", index)
      local literal = next_param and uri:sub(index, next_param - 1) or uri:sub(index)
      table.insert(out, escape(literal))
      index = index + #literal
    end
  end

  table.insert(out, "$")
  return table.concat(out)
end

--- Patterns are built once per route and kept on the route itself: the
--- table is rebuilt from cache on every session, so this stays local.
local function patterns(route)
  if not route.patterns then
    route.patterns = vim.tbl_map(M.to_lua_pattern, M.expand_optionals(route.uri))
  end
  return route.patterns
end

---@param route table
---@param path string
---@return boolean
function M.matches_path(route, path)
  for _, pattern in ipairs(patterns(route)) do
    if path:match(pattern) then
      return true
    end
  end
  return false
end

---@param route table
---@param verb string
---@return boolean
function M.matches_verb(route, verb)
  if route.verb == nil or route.verb == "" then
    return true -- mounted routes and `match` without a verb
  end
  for candidate in route.verb:gmatch("[^|]+") do
    if vim.trim(candidate):upper() == verb:upper() then
      return true
    end
  end
  return false
end

--- Every route matching `path`, in definition order, which is the order
--- Rails itself resolves them in: the first match is the one the running
--- app would serve.
---
--- Routes matching the path but not the verb come back separately so the
--- caller can say "that URL only exists as POST" instead of finding nothing.
---@param routes table[]
---@param path string
---@param verb string
---@return table[] matching path and verb
---@return table[] matching path only
function M.find(routes, path, verb)
  local exact, path_only = {}, {}

  for _, route in ipairs(routes) do
    if M.matches_path(route, path) then
      table.insert(M.matches_verb(route, verb) and exact or path_only, route)
    end
  end

  return exact, path_only
end

return M
