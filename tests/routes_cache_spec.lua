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
end)
