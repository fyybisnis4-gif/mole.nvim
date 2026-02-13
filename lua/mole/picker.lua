local M = {}

local function get_sessions(session_dir)
  local files = vim.fn.glob(session_dir .. "/*.md", false, true)
  table.sort(files, function(a, b)
    return vim.fn.getftime(a) > vim.fn.getftime(b)
  end)
  return files
end

local function display_name(file_path)
  return vim.fn.fnamemodify(file_path, ":t:r")
end

local function pick_telescope(files, on_choice)
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  pickers
    .new({}, {
      prompt_title = "Resume Mole Session",
      finder = finders.new_table({
        results = files,
        entry_maker = function(file_path)
          return {
            value = file_path,
            display = display_name(file_path),
            ordinal = display_name(file_path),
            path = file_path,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      previewer = conf.file_previewer({}),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local entry = action_state.get_selected_entry()
          if entry then
            on_choice(entry.value)
          end
        end)
        return true
      end,
    })
    :find()
end

local function pick_snacks(files, on_choice)
  local items = {}
  for _, file_path in ipairs(files) do
    table.insert(items, {
      text = display_name(file_path),
      file = file_path,
    })
  end

  Snacks.picker({
    title = "Resume Mole Session",
    items = items,
    format = "text",
    preview = "file",
    confirm = function(picker, item)
      picker:close()
      if item then
        on_choice(item.file)
      end
    end,
  })
end

local function pick_select(files, on_choice)
  vim.ui.select(files, {
    prompt = "Resume Mole Session:",
    format_item = display_name,
  }, function(choice)
    if choice then
      on_choice(choice)
    end
  end)
end

local function resolve_picker(picker)
  if picker == "telescope" then
    return pick_telescope
  elseif picker == "snacks" then
    return pick_snacks
  elseif picker == "select" then
    return pick_select
  end

  -- "auto": try telescope → snacks → vim.ui.select
  if pcall(require, "telescope") then
    return pick_telescope
  end
  if pcall(function()
    return Snacks.picker
  end) then
    return pick_snacks
  end
  return pick_select
end

function M.pick_session(config, on_choice)
  local files = get_sessions(config.session_dir)
  if #files == 0 then
    vim.notify("No session files found in " .. config.session_dir, vim.log.levels.INFO)
    return
  end

  local picker_fn = resolve_picker(config.picker)
  picker_fn(files, on_choice)
end

return M
