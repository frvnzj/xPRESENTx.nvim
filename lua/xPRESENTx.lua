local M = {}

local function create_floating_window(config, enter)
  if enter == nil then
    enter = false
  end

  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, enter or false, config)

  return { buf = buf, win = win }
end

--- Default executor for lua code
local execute_lua_code = function(block)
  local original_print = print

  local output = {}

  print = function(...)
    local args = { ... }
    local message = table.concat(vim.tbl_map(tostring, args), "\t")
    table.insert(output, message)
  end

  local chunk = loadstring(block.body)
  pcall(function()
    if not chunk then
      table.insert(output, " <<<BrokenCode>>>")
    else
      chunk()
    end

    return output
  end)

  print = original_print

  return output
end

M.create_system_executor = function(program)
  return function(block)
    local tempfile = vim.fn.tempname()
    vim.fn.writefile(vim.split(block.body, "\n"), tempfile)
    local result = vim.system({ program, tempfile }, { text = true }):wait()
    return vim.split(result.stdout, "\n")
  end
end

local options = {
  executors = {
    lua = execute_lua_code,
    javascript = M.create_system_executor("node"),
    python = M.create_system_executor("python"),
  },
}

M.setup = function(opts)
  opts = opts or {}
  opts.executors = opts.executors or {}

  opts.executors.lua = opts.executors.lua or execute_lua_code
  opts.executors.javascript = opts.executors.lua or M.create_system_executor("node")
  opts.executors.python = opts.executors.lua or M.create_system_executor("python")

  options = opts
end

---@class xPRESENTx.Slides
---@field slides xPRESENTx.Slide[]: Los slides del archivo

---@class xPRESENTx.Slide
---@field title string: El título del slide
---@field body string[]: El cuerpo del slide
---@field blocks xPRESENTx.block[]: Un codeblock en el slide
---@field images string[]: Ruta de las imágenes

---@class xPRESENTx.block
---@field language string: El lenguaje del codeblock
---@field body string: El body del codeblock

--- Formatear líneas
---@param lines string[]: Líneas en el buffer
---@return xPRESENTx.Slides
local parse_slides = function(lines)
  local slides = { slides = {} }
  local current_slide = {
    title = "",
    body = {},
    blocks = {},
    images = {},
  }

  local separator = "^#"
  local slide_separator = "<!%-%-%s*slide%s*%-%->"

  for _, line in ipairs(lines) do
    if line:find(separator) then
      if #current_slide.title > 0 then
        table.insert(slides.slides, current_slide)
      end

      current_slide = {
        title = line,
        body = {},
        blocks = {},
        images = {},
      }
    else
      if line:match("^!%[.+%]%((.+)%)$") then
        local image_path = line:match("^!%[.+%]%((.+)%)$")
        table.insert(current_slide.images, image_path)
      elseif line:find(slide_separator) then
        table.insert(slides.slides, current_slide)
        current_slide = {
          title = current_slide.title,
          body = {},
          blocks = {},
          images = {},
        }
      else
        table.insert(current_slide.body, line)
      end
    end
  end
  table.insert(slides.slides, current_slide)

  for _, slide in ipairs(slides.slides) do
    local block = {
      language = nil,
      body = "",
    }
    local inside_block = false
    for _, line in ipairs(slide.body) do
      if vim.startswith(line, "```") then
        if not inside_block then
          inside_block = true
          block.language = string.sub(line, 4)
        else
          inside_block = false
          block.body = vim.trim(block.body)
          table.insert(slide.blocks, block)
        end
      else
        if inside_block then
          block.body = block.body .. line .. "\n"
        end
      end
    end
  end

  return slides
end

local create_window_configurations = function()
  local width = vim.o.columns
  local height = vim.o.lines

  local header_height = 1 + 2
  local footer_height = 1
  local body_height = height - header_height - footer_height - 2 - 1

  return {
    background = {
      relative = "editor",
      width = width,
      height = height,
      style = "minimal",
      col = 0,
      row = 0,
      zindex = 1,
    },
    header = {
      relative = "editor",
      width = width,
      height = 1,
      style = "minimal",
      border = "rounded",
      col = 0,
      row = 0,
      zindex = 2,
    },
    body = {
      relative = "editor",
      width = width - 8,
      height = body_height,
      style = "minimal",
      border = { " ", " ", " ", " ", " ", " ", " ", " " },
      col = 8,
      row = 4,
    },
    footer = {
      relative = "editor",
      width = width,
      height = 1,
      style = "minimal",
      col = 0,
      row = height - 1,
      zindex = 3,
    },
  }
end

local state = {
  parsed = {},
  current_slide = 1,
  floats = {},
  images = {},
}

local foreach_float = function(cb)
  for name, float in pairs(state.floats) do
    cb(name, float)
  end
end

local xPRESENTx_keymap = function(mode, key, callback)
  vim.keymap.set(mode, key, callback, {
    buffer = state.floats.body.buf,
  })
end

local render_images = function(images)
  for _, img in ipairs(state.images) do
    img:clear()
  end

  state.images = {}
  local image_api = require("image")

  for _, path in ipairs(images) do
    local image = image_api.from_file(path, {
      x = math.floor(vim.o.columns * 0.5),
      y = math.floor(vim.o.lines * 0.5),
      width = math.floor(vim.o.columns * 0.5) - 4,
      height = math.floor(vim.o.lines * 0.5),
    })
    image:render()
    table.insert(state.images, image)
  end
end

M.start_xPRESENTx = function(opts)
  opts = opts or {}
  opts.bufnr = opts.bufnr or 0

  local lines = vim.api.nvim_buf_get_lines(opts.bufnr, 0, -1, false)
  state.parsed = parse_slides(lines)
  state.current_slide = 1
  state.title = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(opts.bufnr), ":t")

  local windows = create_window_configurations()
  state.floats.background = create_floating_window(windows.background)
  state.floats.header = create_floating_window(windows.header)
  state.floats.body = create_floating_window(windows.body, true)
  state.floats.footer = create_floating_window(windows.footer)

  foreach_float(function(_, float)
    vim.bo[float.buf].filetype = "markdown"
  end)

  local set_slide_content = function(idx)
    local width = vim.o.columns

    local slide = state.parsed.slides[idx]

    local padding = string.rep(" ", (width - #slide.title) / 2)
    local title = padding .. slide.title
    vim.api.nvim_buf_set_lines(state.floats.header.buf, 0, -1, false, { title })
    vim.api.nvim_buf_set_lines(state.floats.body.buf, 0, -1, false, slide.body)

    local footer = string.format("  %d / %d | %s", state.current_slide, #state.parsed.slides, state.title)
    vim.api.nvim_buf_set_lines(state.floats.footer.buf, 0, -1, false, { footer })

    render_images(slide.images)
  end

  xPRESENTx_keymap("n", "n", function()
    state.current_slide = math.min(state.current_slide + 1, #state.parsed.slides)
    set_slide_content(state.current_slide)
  end)

  xPRESENTx_keymap("n", "p", function()
    state.current_slide = math.max(state.current_slide - 1, 1)
    set_slide_content(state.current_slide)
  end)

  xPRESENTx_keymap("n", "q", function()
    vim.api.nvim_win_close(state.floats.body.win, true)
  end)

  xPRESENTx_keymap("n", "X", function()
    local slide = state.parsed.slides[state.current_slide]

    local block = slide.blocks[1]
    if not block then
      print("No hay codeblocks en este slide")
      return
    end

    local executor = options.executors[block.language]
    if not executor then
      print("No hay executor válido para este lenguaje")
      return
    end

    local output = { "# Code", "", "```" .. block.language }
    vim.list_extend(output, vim.split(block.body, "\n"))
    table.insert(output, "```")

    table.insert(output, "")
    table.insert(output, "# Output")
    table.insert(output, "")
    table.insert(output, "```")
    vim.list_extend(output, executor(block))
    table.insert(output, "```")

    local buf = vim.api.nvim_create_buf(false, true)
    local temp_width = math.floor(vim.o.columns * 0.8)
    local temp_height = math.floor(vim.o.lines * 0.8)
    vim.api.nvim_open_win(buf, true, {
      relative = "editor",
      style = "minimal",
      noautocmd = true,
      width = temp_width,
      height = temp_height,
      col = math.floor((vim.o.columns - temp_width) / 2),
      row = math.floor((vim.o.lines - temp_height) / 2),
      border = "rounded",
    })

    vim.bo[buf].filetype = "markdown"
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, output)
  end)

  xPRESENTx_keymap("n", "I", function()
    local slide = state.parsed.slides[state.current_slide]

    if not slide or #slide.images == 0 then
      print("No hay imágenes en este slide")
      return
    end

    local image_path = slide.images[1]
    local image_api = require("image")

    local buf = vim.api.nvim_create_buf(false, true)
    local temp_width = math.floor(vim.o.columns * 0.8)
    local temp_height = math.floor(vim.o.lines * 0.8)

    vim.api.nvim_open_win(buf, true, {
      relative = "editor",
      style = "minimal",
      noautocmd = true,
      width = temp_width,
      height = temp_height,
      col = math.floor((vim.o.columns - temp_width) / 2),
      row = math.floor((vim.o.lines - temp_height) / 2),
      border = { " ", " ", " ", " ", " ", " ", " ", " " },
    })

    vim.bo[buf].filetype = "markdown"

    local image = image_api.from_file(image_path, {
      buffer = buf,
      width = temp_width,
      height = temp_height,
      x = math.floor((vim.o.columns - temp_width) / 2) + 3,
      y = math.floor((vim.o.lines - temp_height) / 2) + 1,
    })

    image:render()

    vim.api.nvim_create_autocmd("BufLeave", {
      buffer = buf,
      callback = function()
        image:clear()
      end,
    })
  end)

  local restore = {
    cmdheight = {
      original = vim.o.cmdheight,
      xPRESENTx = 0,
    },
  }

  for option, config in pairs(restore) do
    vim.opt[option] = config.xPRESENTx
  end

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = state.floats.body.buf,
    callback = function()
      for option, config in pairs(restore) do
        vim.opt[option] = config.original
      end

      foreach_float(function(_, float)
        pcall(vim.api.nvim_win_close, float.win, true)
      end)

      for _, img in ipairs(state.images) do
        img:clear()
      end
    end,
  })

  vim.api.nvim_create_autocmd("VimResized", {
    group = vim.api.nvim_create_augroup("xPRESENTx-resized", {}),
    callback = function()
      if not vim.api.nvim_win_is_valid(state.floats.body.win) or state.floats.body.win == nil then
        return
      end

      local updated = create_window_configurations()
      foreach_float(function(name, _)
        vim.api.nvim_win_set_config(state.floats[name].win, updated[name])
      end)

      set_slide_content(state.current_slide)
    end,
  })

  set_slide_content(state.current_slide)
end

-- vim.print(parse_slides({
--   "# Hola",
--   "Esta es una prueba del plugin",
--   "![Imágen](assets/prueba.png)",
--   "# mundo",
--   "Una línea más para la prueba",
-- }))

-- M.start_xPRESENTx({ bufnr = 13 })

M._parse_slides = parse_slides

return M
