local M = {}

M.state = {
  winid = nil,
  visible = false,
}

local function parse_location(line)
  local file, start_line, end_line = line:match("`([^:]+):(%d+)-(%d+)`")
  if file then
    return file, tonumber(start_line), tonumber(end_line)
  end

  file, start_line = line:match("`([^:]+):(%d+)`")
  if file then
    return file, tonumber(start_line), tonumber(start_line)
  end

  return nil, nil, nil
end

local function find_target_win(mole_winid)
  local wins = vim.api.nvim_tabpage_list_wins(0)
  for _, winid in ipairs(wins) do
    if winid ~= mole_winid then
      return winid
    end
  end
  return nil
end

local function jump_to_location()
  local line = vim.api.nvim_get_current_line()
  local file, start_line, _ = parse_location(line)

  if not file then
    return
  end

  local target_win = find_target_win(M.state.winid)
  if not target_win then
    return
  end

  local abs_path = vim.fn.fnamemodify(file, ":p")
  local existing_buf = vim.fn.bufnr(abs_path)

  if existing_buf == -1 and vim.fn.filereadable(abs_path) ~= 1 then
    vim.notify("File not found: " .. file, vim.log.levels.WARN)
    return
  end

  vim.api.nvim_set_current_win(target_win)

  if existing_buf ~= -1 then
    vim.api.nvim_set_current_buf(existing_buf)
  else
    vim.cmd("edit " .. vim.fn.fnameescape(file))
  end

  vim.api.nvim_win_set_cursor(0, { start_line, 0 })
  vim.cmd("normal! zz")
end

function M._setup_jump_keymaps(config, bufnr)
  local keys = config.keys.jump_to_location
  if not keys or keys == "" then
    return
  end
  if type(keys) ~= "string" and type(keys) ~= "table" then
    vim.notify("mole: jump_to_location must be a string or table of strings", vim.log.levels.WARN)
    return
  end
  if type(keys) == "string" then
    keys = { keys }
  end
  for _, key in ipairs(keys) do
    vim.keymap.set("n", key, jump_to_location, { buffer = bufnr, noremap = true, silent = true })
  end
end

function M.open(config, bufnr)
  if M.state.visible and M.state.winid and vim.api.nvim_win_is_valid(M.state.winid) then
    return
  end

  local width = config.window.width

  -- Open a vertical split on the right
  vim.cmd("botright vsplit")
  local winid = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(winid, bufnr)

  -- Resize to configured width
  local total_width = vim.o.columns
  local win_width = math.floor(total_width * width)
  vim.api.nvim_win_set_width(winid, win_width)

  vim.api.nvim_set_option_value("wrap", true, { win = winid })
  vim.api.nvim_set_option_value("conceallevel", 2, { win = winid })
  vim.api.nvim_set_option_value("winfixwidth", true, { win = winid })

  M.state.winid = winid
  M.state.visible = true

  M._setup_jump_keymaps(config, bufnr)

  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(winid),
    once = true,
    callback = function()
      M.state.winid = nil
      M.state.visible = false
    end,
  })

  vim.cmd("wincmd p")
end

function M.close()
  if M.state.winid and vim.api.nvim_win_is_valid(M.state.winid) then
    vim.api.nvim_win_close(M.state.winid, true)
  end
  M.state.winid = nil
  M.state.visible = false
end

function M.toggle(config, bufnr)
  if M.state.visible and M.state.winid and vim.api.nvim_win_is_valid(M.state.winid) then
    M.close()
  else
    M.open(config, bufnr)
  end
end

function M.refresh(bufnr)
  if M.state.winid and vim.api.nvim_win_is_valid(M.state.winid) then
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    vim.api.nvim_win_set_cursor(M.state.winid, { line_count, 0 })
  end
end

return M
