---@diagnostic disable: undefined-field
local parse = require("xPRESENTx")._parse_slides
local eq = assert.are.same

describe("xPRESENTx.parse_slides", function()
  it("should parse an empty file", function()
    eq({
      slides = {
        {
          title = "",
          body = {},
          blocks = {},
        },
      },
    }, parse({}))
  end)

  it("should parse a file with one slide", function()
    eq(
      {
        slides = {
          {
            title = "# First slide",
            body = {
              "Cuerpo del slide",
            },
            blocks = {},
          },
        },
      },
      parse({
        "# First slide",
        "Cuerpo del slide",
      })
    )
  end)

  it("should parse a file with one slide, and a block", function()
    local results = parse({
      "# First slide",
      "Cuerpo del slide",
      "```lua",
      "print('hello world')",
      "```",
    })

    eq(1, #results.slides)
    local slide = results.slides[1]
    eq("# First slide", slide.title)
    eq({
      "Cuerpo del slide",
      "```lua",
      "print('hello world')",
      "```",
    }, slide.body)

    eq({
      language = "lua",
      body = "print('hello world')",
    }, slide.blocks[1])
  end)
end)
