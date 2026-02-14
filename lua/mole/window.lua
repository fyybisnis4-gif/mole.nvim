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

local function read_project_dir(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 20, false)
  for _, l in ipairs(lines) do
    local dir = l:match("%*%*Project:%*%* (.+)")
    if dir then
      return dir
    end
  end
  return nil
end

local function resolve_file(file, bufnr)
  local abs_path = vim.fn.fnamemodify(file, ":p")
  local buf = vim.fn.bufnr(abs_path)
  if buf ~= -1 then
    return abs_path, buf
  end
  if vim.fn.filereadable(abs_path) == 1 then
    return abs_path, -1
  end

  local project_dir = read_project_dir(bufnr)
  if project_dir then
    local project_path = project_dir .. "/" .. file
    buf = vim.fn.bufnr(project_path)
    if buf ~= -1 then
      return project_path, buf
    end
    if vim.fn.filereadable(project_path) == 1 then
      return project_path, -1
    end
  end

  return nil, -1
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

  local session_bufnr = vim.api.nvim_win_get_buf(M.state.winid)
  local resolved, existing_buf = resolve_file(file, session_bufnr)

  if not resolved then
    vim.notify("File not found: " .. file, vim.log.levels.WARN)
    return
  end

  vim.api.nvim_set_current_win(target_win)

  if existing_buf ~= -1 then
    vim.fn.bufload(existing_buf)
    vim.api.nvim_set_current_buf(existing_buf)
  else
    local bufnr = vim.fn.bufadd(resolved)
    vim.fn.bufload(bufnr)
    vim.api.nvim_set_current_buf(bufnr)
  end

  local line_count = vim.api.nvim_buf_line_count(0)
  if start_line > line_count then
    vim.notify("Line " .. start_line .. " no longer exists in " .. file, vim.log.levels.WARN)
  else
    vim.api.nvim_win_set_cursor(0, { start_line, 0 })
    vim.cmd("normal! zz")
  end
end

local function next_annotation()
  local line_count = vim.api.nvim_buf_line_count(0)
  local cursor = vim.api.nvim_win_get_cursor(0)[1]
  for i = cursor + 1, line_count do
    local l = vim.api.nvim_buf_get_lines(0, i - 1, i, false)[1]
    if parse_location(l) then
      vim.api.nvim_win_set_cursor(0, { i, 0 })
      return
    end
  end
end

local function prev_annotation()
  local cursor = vim.api.nvim_win_get_cursor(0)[1]
  for i = cursor - 1, 1, -1 do
    local l = vim.api.nvim_buf_get_lines(0, i - 1, i, false)[1]
    if parse_location(l) then
      vim.api.nvim_win_set_cursor(0, { i, 0 })
      return
    end
  end
end

local function set_keys(bufnr, keys, fn, desc)
  if not keys or keys == "" then
    return
  end
  if type(keys) ~= "string" and type(keys) ~= "table" then
    vim.notify("mole: keymap must be a string or table of strings", vim.log.levels.WARN)
    return
  end
  if type(keys) == "string" then
    keys = { keys }
  end
  for _, key in ipairs(keys) do
    vim.keymap.set("n", key, fn, { buffer = bufnr, noremap = true, silent = true, desc = desc })
  end
end

function M._setup_jump_keymaps(config, bufnr)
  set_keys(bufnr, config.keys.jump_to_location, jump_to_location, "Mole: Jump to location")
  set_keys(bufnr, config.keys.next_annotation, next_annotation, "Mole: Next annotation")
  set_keys(bufnr, config.keys.prev_annotation, prev_annotation, "Mole: Previous annotation")
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
