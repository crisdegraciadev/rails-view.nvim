local helpers = require("tests.helpers")
local matcher = require("rails-view.matcher")
local routes_mod = require("rails-view.routes")

describe("matcher.expand_optionals", function()
  it("expands every combination of optional groups", function()
    local variants = matcher.expand_optionals("/posts(/:id)(.:format)")
    table.sort(variants)
    assert.same({ "/posts", "/posts.:format", "/posts/:id", "/posts/:id.:format" }, variants)
  end)

  it("leaves a URI without optional groups alone", function()
    assert.same({ "/posts" }, matcher.expand_optionals("/posts"))
  end)
end)

describe("matcher.to_lua_pattern", function()
  it("gives :params a single segment", function()
    local pattern = matcher.to_lua_pattern("/companies/:company_id/jobs")
    assert.is_truthy(("/companies/42/jobs"):match(pattern))
    assert.is_nil(("/companies/42/nested/jobs"):match(pattern))
  end)

  it("escapes literals so a dot is a dot", function()
    local pattern = matcher.to_lua_pattern("/jobs.json")
    assert.is_nil(("/jobsXjson"):match(pattern))
  end)
end)

describe("matcher.find", function()
  local routes = routes_mod.parse(helpers.fixture("routes_expanded.txt"))

  local function resolve(path, verb)
    local exact = matcher.find(routes, path, verb or "GET")
    return exact[1]
  end

  it("fills in a :param", function()
    local route = resolve("/companies/bizneo/jobs")
    assert.equals("companies/recruiting/jobs", route.controller)
    assert.equals("index", route.action)
  end)

  it("tells the same URI apart by verb", function()
    assert.equals("create", resolve("/companies/bizneo/jobs", "POST").action)
  end)

  it("matches an explicit format", function()
    assert.equals("index", resolve("/companies/bizneo/jobs.json").action)
  end)

  it("matches a :param sitting inside a segment", function()
    assert.equals("api/v3/sessions", resolve("/api/v3/sessions", "POST").controller)
  end)

  it("lets a *glob swallow the rest of the path", function()
    local route = resolve("/rails/active_storage/blobs/redirect/abc123/folder/cv.pdf")
    assert.equals("active_storage/blobs/redirect", route.controller)
  end)

  it("matches the root", function()
    assert.equals("sessions", resolve("/").controller)
  end)

  it("returns the verb mismatch separately instead of nothing", function()
    local exact, path_only = matcher.find(routes, "/companies/bizneo/jobs", "DELETE")
    assert.equals(0, #exact)
    assert.is_true(#path_only > 0)
  end)

  it("invents nothing", function()
    assert.is_nil(resolve("/does/not/exist"))
  end)
end)
