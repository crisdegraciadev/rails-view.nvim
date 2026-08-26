local M = {}

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

return M
