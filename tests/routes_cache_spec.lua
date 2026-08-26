local config = require("rails-view.config")
local helpers = require("tests.helpers")
local routes = require("rails-view.routes")

describe("the routes cache", function()
  local app, cache_dir

  before_each(function()
    app = helpers.temp_app()
    cache_dir = vim.fn.tempname()
    config.setup({ cache_dir = cache_dir })
  end)

  after_each(function()
    helpers.remove(app)
    helpers.remove(cache_dir)
    config.setup({})
  end)

  it("has nothing to give before anything is saved", function()
    assert.is_nil(routes.load_cache(app))
  end)

  it("gives back what was saved", function()
    local parsed = routes.parse(helpers.fixture("routes_expanded.txt"))
    routes.save_cache(app, parsed)

    local loaded = routes.load_cache(app)
    assert.equals(#parsed, #loaded)
    assert.equals(parsed[2].controller, loaded[2].controller)
  end)

  it("refuses a cache written for different route files", function()
    routes.save_cache(app, routes.parse(helpers.fixture("routes_expanded.txt")))
    vim.fn.writefile({ "# changes the fingerprint" }, app .. "/config/routes/api.rb")

    assert.is_nil(routes.load_cache(app))
  end)

  it("still has the table for a branch after moving away and back", function()
    local on_main = routes.parse(helpers.fixture("routes_expanded.txt"))
    local main_routes = vim.fn.readfile(app .. "/config/routes.rb")
    routes.save_cache(app, on_main)

    -- Check out a branch whose routes differ, and build there too.
    vim.fn.writefile({ "Rails.application.routes.draw do", "  # one more route", "end" }, app .. "/config/routes.rb")
    assert.is_nil(routes.load_cache(app))
    routes.save_cache(app, { on_main[1] })
    assert.equals(1, #routes.load_cache(app))

    -- Back to the first branch: nothing to rebuild.
    vim.fn.writefile(main_routes, app .. "/config/routes.rb")
    assert.equals(#on_main, #routes.load_cache(app))
  end)

  it("keeps no more tables than cache_entries", function()
    config.setup({ cache_dir = cache_dir, cache_entries = 2 })
    local parsed = routes.parse(helpers.fixture("routes_expanded.txt"))

    for index = 1, 4 do
      vim.fn.writefile({ "# state " .. index }, app .. "/config/routes.rb")
      routes.save_cache(app, parsed)
    end

    assert.equals(2, #require("rails-view.project").cache_files(app))
  end)

  it("invalidate drops every table for the project", function()
    for index = 1, 2 do
      vim.fn.writefile({ "# state " .. index }, app .. "/config/routes.rb")
      routes.save_cache(app, routes.parse(helpers.fixture("routes_expanded.txt")))
    end

    routes.invalidate(app)

    assert.equals(0, #require("rails-view.project").cache_files(app))
    assert.is_nil(routes.load_cache(app))
  end)
end)
