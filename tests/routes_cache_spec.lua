local config = require("rails-view.config")
local helpers = require("tests.helpers")
local project = require("rails-view.project")
local routes = require("rails-view.routes")
local util = require("rails-view.util")

describe("the routes cache", function()
  local app, cache_dir

  local function parsed()
    return routes.parse(helpers.fixture("routes_expanded.txt"))
  end

  before_each(function()
    app = helpers.temp_app()
    cache_dir = vim.fn.tempname()
    config.setup({ cache_dir = cache_dir })
    routes.invalidate(app)
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
    local table_ = parsed()
    routes.save_cache(app, table_)

    local loaded = routes.load_cache(app)
    assert.equals(#table_, #loaded)
    assert.equals(table_[2].controller, loaded[2].controller)
  end)

  it("keeps serving the cached table after the route files change", function()
    routes.save_cache(app, parsed())
    vim.fn.writefile({ "# another branch, other routes" }, app .. "/config/routes.rb")

    assert.equals(#parsed(), #routes.load_cache(app))
  end)

  it("writes a table the next session can pick up", function()
    routes.save_cache(app, parsed())

    local decoded = vim.json.decode(util.read_file(project.cache_path(app)))
    assert.equals(#parsed(), #decoded.routes)
    assert.is_true(decoded.built_at > 0)
    assert.is_nil(decoded.routes[1].patterns)
  end)

  it("reports being out of date without acting on it", function()
    routes.save_cache(app, parsed())
    assert.is_false(routes.is_stale(app))

    local later = os.time() + 60
    vim.uv.fs_utime(app .. "/config/routes.rb", later, later)

    assert.is_true(routes.is_stale(app))
    assert.is_truthy(routes.load_cache(app))
  end)

  it("is dropped by invalidate, which is what a refresh does first", function()
    routes.save_cache(app, parsed())
    routes.invalidate(app)

    assert.is_nil(routes.load_cache(app))
    assert.is_nil(vim.uv.fs_stat(project.cache_path(app)))
  end)
end)
