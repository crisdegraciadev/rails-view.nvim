local config = require("rails-view.config")

describe("config.setup", function()
  after_each(function()
    config.setup({})
  end)

  it("keeps the defaults for anything not overridden", function()
    config.setup({ default_verb = "POST" })
    assert.equals("POST", config.options.default_verb)
    assert.same({ "bin/rails", "routes", "--expanded" }, config.options.routes_cmd)
  end)

  it("does not let one call leak into the next", function()
    config.setup({ default_verb = "POST" })
    config.setup({})
    assert.equals("GET", config.options.default_verb)
  end)
end)
