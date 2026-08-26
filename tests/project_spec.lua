local config = require("rails-view.config")
local helpers = require("tests.helpers")
local project = require("rails-view.project")

local APP = helpers.root .. "/fixtures/rails_app"

describe("project.root", function()
  after_each(function()
    config.setup({})
  end)

  it("uses the configured root when there is one", function()
    config.setup({ root = APP })
    assert.equals(APP, project.root())
  end)

  it("finds the root from a file deep inside the project", function()
    vim.cmd("edit " .. APP .. "/config/routes.rb")
    assert.equals(APP, project.root())
    vim.cmd("bdelete!")
  end)
end)

describe("project.route_files", function()
  it("collects config/routes.rb and config/routes/**", function()
    local files = project.route_files(APP)
    assert.equals(2, #files)
    assert.is_truthy(files[1]:match("config/routes%.rb$"))
  end)
end)

describe("project.fingerprint", function()
  local app

  before_each(function()
    app = helpers.temp_app()
  end)

  after_each(function()
    helpers.remove(app)
  end)

  it("changes when a route file changes", function()
    local before = project.fingerprint(app)
    vim.fn.writefile({ "# a new route file" }, app .. "/config/routes/api.rb")

    assert.are_not.equals(before, project.fingerprint(app))
  end)

  it("survives a touch, which is what git checkout does to these files", function()
    local before = project.fingerprint(app)

    local later = os.time() + 120
    vim.uv.fs_utime(app .. "/config/routes.rb", later, later)

    assert.equals(before, project.fingerprint(app))
  end)

  it("comes back to the same value when the contents come back", function()
    local original = vim.fn.readfile(app .. "/config/routes.rb")
    local before = project.fingerprint(app)

    vim.fn.writefile({ "# on another branch" }, app .. "/config/routes.rb")
    local other = project.fingerprint(app)

    vim.fn.writefile(original, app .. "/config/routes.rb")

    assert.are_not.equals(before, other)
    assert.equals(before, project.fingerprint(app))
  end)
end)

describe("project.cache_path", function()
  it("gives each project its own file", function()
    assert.are_not.equals(project.cache_path("/one/app", "abc"), project.cache_path("/another/app", "abc"))
    assert.is_truthy(project.cache_path("/one/app", "abc"):match("%.json$"))
  end)

  it("gives each state of the route files its own file", function()
    assert.are_not.equals(project.cache_path("/one/app", "abc"), project.cache_path("/one/app", "def"))
  end)
end)
