local M = {}

M.root = vim.fn.fnamemodify(vim.fn.resolve(debug.getinfo(1, "S").source:sub(2)), ":p:h")

--- Reads a file from tests/fixtures.
---@param name string
---@return string
function M.fixture(name)
  return table.concat(vim.fn.readfile(M.root .. "/fixtures/" .. name), "\n")
end

--- Builds a throwaway project with the shape this plugin looks for. Specs
--- that touch route files need their own copy: the spec files run in
--- parallel and would otherwise see each other's writes.
---@return string root
function M.temp_app()
  local root = vim.fn.tempname()
  vim.fn.mkdir(root .. "/config/routes", "p")
  vim.fn.writefile({ "Rails.application.routes.draw do", "end" }, root .. "/config/routes.rb")
  return root
end

---@param path string
function M.remove(path)
  vim.fn.delete(path, "rf")
end

return M
