local url = require("rails-view.url")

describe("url.parse", function()
  it("rejects empty input", function()
    local result, err = url.parse("", "GET")
    assert.is_nil(result)
    assert.equals("empty URL", err)
  end)

  it("keeps a bare path as-is", function()
    assert.equals("/jobs", url.parse("/jobs", "GET").path)
  end)

  it("falls back to the default verb", function()
    assert.equals("GET", url.parse("/jobs", "GET").verb)
  end)

  it("drops the scheme and the host", function()
    assert.equals("/jobs", url.parse("http://localhost:3001/jobs", "GET").path)
  end)

  it("drops a schemeless host", function()
    assert.equals("/jobs", url.parse("localhost:3001/jobs", "GET").path)
  end)

  it("does not mistake the first segment of a relative path for a host", function()
    assert.equals("/companies/jobs", url.parse("companies/jobs", "GET").path)
  end)

  it("splits off the query and the fragment", function()
    local result = url.parse("/jobs?page=2#top", "GET")
    assert.equals("/jobs", result.path)
    assert.equals("page=2", result.query)
  end)

  it("drops the trailing slash, except on the root", function()
    assert.equals("/jobs", url.parse("/jobs/", "GET").path)
    assert.equals("/", url.parse("/", "GET").path)
  end)

  it("reads an explicit leading verb", function()
    local result = url.parse("POST /jobs", "GET")
    assert.equals("POST", result.verb)
    assert.equals("/jobs", result.path)
  end)

  it("percent-decodes the path", function()
    assert.equals("/companies/my company", url.parse("/companies/my%20company", "GET").path)
  end)
end)

describe("url.looks_like_url", function()
  it("accepts URLs and absolute paths", function()
    assert.is_true(url.looks_like_url("http://localhost:3001/jobs"))
    assert.is_true(url.looks_like_url("/jobs"))
    assert.is_true(url.looks_like_url("localhost:3001/jobs"))
  end)

  it("rejects prose and empty values", function()
    assert.is_false(url.looks_like_url("jobs"))
    assert.is_false(url.looks_like_url(""))
    assert.is_false(url.looks_like_url(nil))
  end)
end)
