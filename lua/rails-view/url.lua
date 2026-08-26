local M = {}

local VERBS = { GET = true, POST = true, PUT = true, PATCH = true, DELETE = true, HEAD = true, OPTIONS = true }

local function percent_decode(str)
  return (str:gsub("%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end))
end

--- Tells a host apart from the first segment of a relative path.
--- Both look the same once the scheme is gone: `localhost:3001/chats`
--- and `trabajar/bizneo` are text, slash, text.
local function looks_like_host(segment)
  return segment:match("^localhost")
    or segment:match(":%d+$")
    or segment:match("^%d+%.%d+%.%d+%.%d+$")
    or segment:match("%.%a%a+$")
end

--- Turns anything URL-shaped into a path and a verb.
---
---   http://localhost:3001/companies/1/jobs?page=2#top
---   localhost:3001/companies/1/jobs
---   /companies/1/jobs
---   POST /companies/1/jobs
---
---@param input string
---@param default_verb string verb to assume when the input carries none
---@return table|nil result { path, query, verb }
---@return string|nil error
function M.parse(input, default_verb)
  if type(input) ~= "string" then
    return nil, "empty URL"
  end

  local raw = vim.trim(input)
  if raw == "" then
    return nil, "empty URL"
  end

  local verb
  local head, rest = raw:match("^(%a+)%s+(.+)$")
  if head and VERBS[head:upper()] then
    verb, raw = head:upper(), vim.trim(rest)
  end

  -- The substitution count doubles as "was there a scheme?". If there was,
  -- whatever follows is a host for certain and no guessing is needed.
  local work, schemes = raw:gsub("^%a[%w+.-]*://", "")

  if not work:match("^/") then
    local first = work:match("^([^/]+)") or work
    if schemes > 0 or looks_like_host(first) then
      work = work:sub(#first + 1)
    else
      work = "/" .. work
    end
  end

  work = work:gsub("#.*$", "")
  local path, query = work:match("^([^?]*)%??(.*)$")

  path = percent_decode(path or "")
  path = path:gsub("//+", "/")
  if path ~= "/" then
    path = path:gsub("/+$", "")
  end
  if path == "" then
    path = "/"
  end

  return {
    path = path,
    query = query ~= "" and query or nil,
    verb = verb or (default_verb or "GET"):upper(),
  }
end

--- Whether a string is worth handing to parse(), used to pre-fill prompts
--- from the clipboard or from the word under the cursor.
---@param text string|nil
---@return boolean
function M.looks_like_url(text)
  if type(text) ~= "string" or text == "" then
    return false
  end
  text = vim.trim(text)
  return text:match("^%a[%w+.-]*://") ~= nil or text:match("^/[%w]") ~= nil or text:match("^localhost:%d+") ~= nil
end

return M
