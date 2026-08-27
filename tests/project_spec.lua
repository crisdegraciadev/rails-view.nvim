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

describe("project.routes_changed_at", function()
  it("reports the most recent change to any route file", function()
    local app = helpers.temp_app()

    local later = os.time() + 120
    vim.uv.fs_utime(app .. "/config/routes.rb", later, later)
    assert.equals(later, project.routes_changed_at(app))

    helpers.remove(app)
  end)
end)

describe("project.cache_path", function()
  it("gives each project its own file", function()
    assert.are_not.equals(project.cache_path("/one/app"), project.cache_path("/another/app"))
    assert.is_truthy(project.cache_path("/one/app"):match("%.json$"))
  end)
end)
