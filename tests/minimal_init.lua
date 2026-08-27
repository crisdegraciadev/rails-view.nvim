-- Runs the specs against this plugin only, ignoring the developer's own config.

-- A test run spawns one Neovim per spec file, and they would all write the
-- shared ShaDa file on exit, racing each other and whatever editor the
-- developer has open. The specs have no state worth keeping anyway.
vim.opt.shadafile = "NONE"

local root = vim.fn.fnamemodify(vim.fn.resolve(debug.getinfo(1, "S").source:sub(2)), ":p:h:h")
vim.opt.runtimepath:prepend(root)

local plenary = vim.fn.stdpath("data") .. "/lazy/plenary.nvim"
if vim.fn.isdirectory(plenary) == 1 then
  vim.opt.runtimepath:prepend(plenary)
end

vim.cmd("runtime plugin/plenary.vim")
