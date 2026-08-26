local M = {}

M.root = vim.fn.fnamemodify(vim.fn.resolve(debug.getinfo(1, "S").source:sub(2)), ":p:h")

--- Reads a file from tests/fixtures.
---@param name string
---@return string
function M.fixture(name)
  return table.concat(vim.fn.readfile(M.root .. "/fixtures/" .. name), "\n")
end

return M
