local M = {}

M.defaults = {
  -- Directory where session markdown files are created
  session_dir = vim.fn.expand("~/.mole"),

  -- What to capture from the visual selection:
  --   "location" => file path + line range
  --   "snippet"  => file path + line range + selected text in fenced code block
  capture_mode = "location",

  -- Open the side panel automatically when starting a session
  auto_open_panel = true,

  -- Custom session name. nil = timestamp, string = use as name, function = call to get name
  session_name = nil,

  -- Show vim.notify messages
  notify = true,

  -- Keybindings
  keys = {
    annotate = "<leader>ma",
    start_session = "<leader>ms",
    stop_session = "<leader>mq",
    toggle_window = "<leader>mw",
  },

  -- Floating window appearance
  window = {
    width = 0.3,
  },

  -- Inline input popup appearance
  input = {
    width = 50,
    border = "rounded",
  },
}

function M.apply(user_config)
  local config = vim.deepcopy(M.defaults)
  if user_config then
    config = vim.tbl_deep_extend("force", config, user_config)
  end
  return config
end

return M
