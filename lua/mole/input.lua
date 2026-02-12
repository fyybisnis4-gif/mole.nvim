local Input = require("nui.input")

local M = {}

---@param config table Plugin config
---@param default_mode string "location" or "snippet"
---@param selection table { start_line, end_line, ... }
---@param callback fun(note: string|nil, mode: string)
function M.show(config, default_mode, selection, callback)
  local mode = default_mode
  local input_conf = config.input

  local function mode_label()
    return " mole [" .. mode .. "] "
  end

  local input = Input({
    relative = "cursor",
    position = {
      row = selection.end_line - selection.start_line + 2,
      col = 0,
    },
    size = {
      width = input_conf.width,
    },
    border = {
      style = input_conf.border,
      text = {
        top = mode_label(),
        top_align = "right",
      },
    },
    win_options = {
      winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
    },
  }, {
    prompt = " > ",
    on_submit = function(value)
      callback(value or "", mode)
    end,
    on_close = function()
      callback(nil, mode)
    end,
  })

  input:map("i", "<Tab>", function()
    mode = mode == "location" and "snippet" or "location"
    input.border:set_text("top", mode_label(), "right")
  end, { noremap = true })

  input:map("i", "<Esc>", function()
    input:unmount()
  end, { noremap = true })

  input:map("n", "<Esc>", function()
    input:unmount()
  end, { noremap = true })

  input:mount()
end

return M
