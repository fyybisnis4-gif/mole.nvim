local M = {}

M.state = {
  winid = nil,
  visible = false,
}

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

  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(winid),
    once = true,
    callback = function()
      M.state.winid = nil
      M.state.visible = false
    end,
  })

  -- Return focus to the previous window
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
