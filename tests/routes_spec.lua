local helpers = require("tests.helpers")
local routes = require("rails-view.routes")

describe("routes.parse", function()
  local parsed = routes.parse(helpers.fixture("routes_expanded.txt"))

  it("skips mounted engines, which have no controller#action", function()
    assert.equals(6, #parsed)
    assert.equals("sessions", parsed[1].controller)
  end)

  it("keeps the prefix, the verb and the URI", function()
    local route = parsed[2]
    assert.equals("company_jobs", route.prefix)
    assert.equals("GET", route.verb)
    assert.equals("/companies/:company_id/jobs(.:format)", route.uri)
    assert.equals("companies/recruiting/jobs", route.controller)
    assert.equals("index", route.action)
  end)

  it("keeps the source location so a route can be opened in routes.rb", function()
    assert.equals("config/routes.rb", parsed[2].source_file)
    assert.equals(553, parsed[2].source_line)
  end)

  it("trims the constraints off controller#action", function()
    local route = parsed[5]
    assert.equals("api/v3/sessions", route.controller)
    assert.equals("create", route.action)
  end)

  it("preserves definition order, which is Rails' own precedence", function()
    assert.equals(1, parsed[1].order)
    assert.equals("create", parsed[3].action)
  end)
end)
