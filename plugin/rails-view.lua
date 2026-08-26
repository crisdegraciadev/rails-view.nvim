if vim.g.loaded_rails_view then
  return
end
vim.g.loaded_rails_view = true

if vim.fn.has("nvim-0.10") == 0 then
  vim.notify("rails-view needs Neovim 0.10 or newer", vim.log.levels.ERROR)
  return
end

local function rails_view()
  return require("rails-view")
end

vim.api.nvim_create_user_command("RailsView", function(opts)
  rails_view().open_or_prompt(opts.args, { target = "view", pick = opts.bang })
end, { nargs = "?", bang = true, desc = "Open the view behind a Rails URL" })

vim.api.nvim_create_user_command("RailsViewController", function(opts)
  rails_view().open_or_prompt(opts.args, { target = "controller", pick = opts.bang })
end, { nargs = "?", bang = true, desc = "Open the controller behind a Rails URL" })

vim.api.nvim_create_user_command("RailsViewAny", function(opts)
  rails_view().open_or_prompt(opts.args, { target = "any", pick = true })
end, { nargs = "?", desc = "Pick between the views and the controller of a Rails URL" })

vim.api.nvim_create_user_command("RailsViewInfo", function(opts)
  local input = vim.trim(opts.args) ~= "" and opts.args or rails_view().guess_url()

  if vim.trim(input) == "" then
    vim.ui.input({ prompt = "URL: " }, function(value)
      if value and vim.trim(value) ~= "" then
        rails_view().info(value)
      end
    end)
  else
    rails_view().info(input)
  end
end, { nargs = "?", desc = "Report what a Rails URL resolves to" })

vim.api.nvim_create_user_command("RailsViewRefresh", function()
  rails_view().refresh()
end, { desc = "Rebuild the cached routing table" })
