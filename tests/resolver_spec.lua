local helpers = require("tests.helpers")
local resolver = require("rails-view.resolver")

local APP = helpers.root .. "/fixtures/rails_app"
local JOBS = "companies/recruiting/jobs"

describe("resolver.views", function()
  it("puts the HTML template first when an action has several", function()
    local views = resolver.views(APP, JOBS, "index")
    assert.equals(2, #views)
    assert.equals("app/views/" .. JOBS .. "/index.html.erb", views[1].relative)
  end)

  it("finds a template whatever the engine", function()
    local views = resolver.views(APP, JOBS, "edit")
    assert.equals("app/views/" .. JOBS .. "/edit.html.slim", views[1].relative)
  end)

  it("does not mistake a partial for an action's template", function()
    assert.equals(0, #resolver.views(APP, JOBS, "form"))
  end)

  it("comes back empty for an action that renders nothing", function()
    assert.equals(0, #resolver.views(APP, JOBS, "create"))
  end)
end)

describe("resolver.controller", function()
  it("points at the line the action is defined on", function()
    local controller = resolver.controller(APP, JOBS, "index")
    assert.equals("app/controllers/" .. JOBS .. "_controller.rb", controller.relative)
    assert.equals(4, controller.line)
  end)

  it("handles a one-line definition", function()
    assert.equals(8, resolver.controller(APP, JOBS, "edit").line)
  end)

  it("still returns the file when the action is inherited", function()
    local controller = resolver.controller(APP, "sessions", "new")
    assert.is_truthy(controller)
    assert.is_nil(controller.line)
  end)

  it("returns nothing when there is no controller file", function()
    assert.is_nil(resolver.controller(APP, "nope/missing", "index"))
  end)
end)
