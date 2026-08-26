local M = {}

function M.notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "rails-view" })
end

function M.warn(message)
  M.notify(message, vim.log.levels.WARN)
end

function M.error(message)
  M.notify(message, vim.log.levels.ERROR)
end

---@param path string
---@return string|nil
function M.read_file(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end

  local contents = file:read("*a")
  file:close()
  return contents
end

---@param path string
---@param contents string
---@return boolean
function M.write_file(path, contents)
  vim.fn.mkdir(vim.fs.dirname(path), "p")

  local file = io.open(path, "w")
  if not file then
    return false
  end

  file:write(contents)
  file:close()
  return true
end

return M
