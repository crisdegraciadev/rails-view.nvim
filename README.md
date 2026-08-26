# rails-view.nvim

Open the view behind a URL from your Rails application.

```
:RailsView http://localhost:3001/companies/bizneo/jobs
```

```
app/views/companies/recruiting/jobs/index.html.erb
```

## Requirements

- Neovim 0.10 or newer
- A Rails application whose routes can be printed from the command line
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) to run the specs

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "rails-view.nvim",
  cmd = { "RailsView", "RailsViewController", "RailsViewAny", "RailsViewInfo", "RailsViewRefresh" },
  opts = {},
  keys = {
    { "<leader>ru", "<cmd>RailsView<cr>", desc = "Rails: view from a URL" },
    { "<leader>rc", "<cmd>RailsViewController<cr>", desc = "Rails: controller from a URL" },
    { "<leader>ri", "<cmd>RailsViewInfo<cr>", desc = "Rails: explain a URL" },
  },
}
```

## Commands

| Command | |
| --- | --- |
| `:RailsView [url]` | Open the view. With `!`, pick among every template of the action. |
| `:RailsViewController [url]` | Open the controller, cursor on the action. |
| `:RailsViewAny [url]` | Pick between the views and the controller. |
| `:RailsViewInfo [url]` | Report the route, its helper, its line in `routes.rb`, its templates and its controller. |
| `:RailsViewRefresh` | Rebuild the cached routing table. |

Called without an argument, the commands ask for a URL and offer the one under
the cursor or the last one copied.

Accepted input:

```
http://localhost:3001/companies/bizneo/jobs?page=2#top
localhost:3001/companies/bizneo/jobs
/companies/bizneo/jobs
POST /companies/bizneo/jobs
```

Without an explicit verb, `GET` is assumed. If the path only exists under a
different verb, that one is used and the substitution is reported.

## Configuration

```lua
require("rails-view").setup({
  root = nil,
  routes_cmd = { "bin/rails", "routes", "--expanded" },
  routes_timeout = 180000,
  cache_dir = vim.fn.stdpath("cache") .. "/rails-view",
  open_cmd = "edit",
  pick = "auto",
  default_verb = "GET",
  auto_refresh = true,
  view_dirs = { "app/views" },
  controller_dirs = { "app/controllers" },
  template_priority = {
    "html.erb",
    "html.slim",
    "html.haml",
    "turbo_stream.erb",
    "turbo_stream.slim",
    "js.erb",
    "json.jbuilder",
  },
})
```

For Rails in a container:

```lua
routes_cmd = { "docker", "compose", "exec", "-T", "web", "bin/rails", "routes", "--expanded" }
```

`:checkhealth rails-view` reports the detected project, the routes command
and the state of the cache.

## How it works

A `config.routes.rb` of any size resolves nothing on its own. `path:`, an
explicit `controller:`, nested namespaces and concerns all move a route
somewhere other than where it is written, and following that by hand means
reimplementing the Rails router.

Rails already knows the answer and can print it, so this plugin reads
`rails routes --expanded` and works from that. Matching follows the same rules
as the router: `:param` takes one segment, `*glob` takes the rest, parentheses
mark optional parts, and when several routes match, the first one in definition
order wins, exactly as it would in the running application.

Printing the table means booting Rails, which takes tens of seconds on a large
application, so the result is cached per project in
`stdpath("cache")/rails-view/`. The cache is keyed by the size and mtime of
every route file, which is what makes it expire on its own. The command runs
through `vim.system`, so the editor stays usable while it does.

## Development

```
make test    # run the specs
make lint    # check formatting with stylua
```

The specs run against a minimal init and never boot Rails: the parser is fed a
recorded `rails routes --expanded` output from `tests/fixtures`, and the file
lookups run against a small Rails-shaped tree in `tests/fixtures/rails_app`.
