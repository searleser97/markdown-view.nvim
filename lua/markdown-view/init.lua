local config = require('markdown-view.config')
local renderer = require('markdown-view.renderer')

local M = {}

local namespace = vim.api.nvim_create_namespace('markdown_view_nvim')
local group = vim.api.nvim_create_augroup('markdown_view_nvim', { clear = true })
local views = {}
local source_views = {}
local generations = {}

local function define_highlights()
  vim.api.nvim_set_hl(0, 'MarkdownViewTableBorder', { link = 'Comment', default = true })
  vim.api.nvim_set_hl(0, 'MarkdownViewTableHeader', { link = 'Title', default = true })
  vim.api.nvim_set_hl(0, 'MarkdownViewTableRow', { link = 'Normal', default = true })
end

define_highlights()
vim.api.nvim_create_autocmd('ColorScheme', {
  group = group,
  callback = define_highlights,
})

local function cleanup_state(view_buf, state)
  if state and state.source_autocmd then
    pcall(vim.api.nvim_del_autocmd, state.source_autocmd)
  end
  if state and state.source_wipe_autocmd then
    pcall(vim.api.nvim_del_autocmd, state.source_wipe_autocmd)
  end
  views[view_buf] = nil
  if state then
    source_views[state.source_buf] = nil
  end
  generations[view_buf] = nil
end

local function eligible(buf)
  return config.values.enabled
    and vim.api.nvim_buf_is_valid(buf)
    and vim.tbl_contains(config.values.file_types, vim.bo[buf].filetype)
    and not vim.api.nvim_buf_get_name(buf):match('^markdown%-view://')
end

local function clamp_cursor(buf, cursor)
  local line_count = math.max(vim.api.nvim_buf_line_count(buf), 1)
  local line = math.max(1, math.min(cursor[1], line_count))
  local text = vim.api.nvim_buf_get_lines(buf, line - 1, line, false)[1] or ''
  return { line, math.max(0, math.min(cursor[2], #text)) }
end

local function source_cursor(state, view_cursor)
  local line = state.source_map and state.source_map[view_cursor[1]] or view_cursor[1]
  return clamp_cursor(state.source_buf, { line or 1, view_cursor[2] })
end

local function view_cursor(state, source_position)
  local target = source_position[1]
  local best_line = 1
  local best_distance = math.huge
  for line, source_line in ipairs(state.source_map or {}) do
    local distance = math.abs(source_line - target)
    if distance < best_distance then
      best_line = line
      best_distance = distance
    end
  end
  return clamp_cursor(state.view_buf, { best_line, source_position[2] })
end

local function set_cursor(win, buf, cursor)
  if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
    vim.api.nvim_win_set_cursor(win, clamp_cursor(buf, cursor))
  end
end

local function refresh_markdown(state)
  if not vim.api.nvim_win_is_valid(state.win) or vim.api.nvim_win_get_buf(state.win) ~= state.view_buf then
    state.markdown_dirty = true
    return
  end
  vim.api.nvim_buf_call(state.view_buf, function()
    require('render-markdown').buf_enable()
  end)
  vim.api.nvim_exec_autocmds('TextChanged', {
    buffer = state.view_buf,
    modeline = false,
  })
  state.markdown_dirty = false
end

local function show_source(view_buf)
  local state = views[view_buf]
  if not state or not vim.api.nvim_buf_is_valid(state.source_buf) then
    return
  end
  local position = state.last_source_cursor or { 1, 0 }
  if vim.api.nvim_win_is_valid(state.win) and vim.api.nvim_win_get_buf(state.win) == view_buf then
    position = source_cursor(state, vim.api.nvim_win_get_cursor(state.win))
  end
  state.last_source_cursor = position

  if state.mode == 'tab' and vim.api.nvim_win_is_valid(state.source_win) then
    vim.api.nvim_set_current_win(state.source_win)
    set_cursor(state.source_win, state.source_buf, position)
  elseif vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_set_buf(state.win, state.source_buf)
    set_cursor(state.win, state.source_buf, position)
  end
end

local function show_view(view_buf, source_position)
  local state = views[view_buf]
  if not state or not vim.api.nvim_buf_is_valid(view_buf) then
    return
  end
  source_position = source_position or state.last_source_cursor or { 1, 0 }
  state.pending_source_cursor = source_position

  if vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_set_current_win(state.win)
    if vim.api.nvim_win_get_buf(state.win) ~= view_buf then
      vim.api.nvim_win_set_buf(state.win, view_buf)
    end
    if state.source_map then
      set_cursor(state.win, view_buf, view_cursor(state, source_position))
      state.pending_source_cursor = nil
    end
    if state.markdown_dirty then
      refresh_markdown(state)
    end
  end
end

local function close_view(buf)
  local state = views[buf]
  if not state then
    return
  end
  show_source(buf)
  cleanup_state(buf, state)

  if state.mode == 'tab' and vim.api.nvim_win_is_valid(state.win) then
    local tab = vim.api.nvim_win_get_tabpage(state.win)
    if vim.api.nvim_tabpage_is_valid(tab) then
      vim.api.nvim_set_current_tabpage(tab)
      vim.cmd('tabclose')
    end
  end
  if vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_delete(buf, { force = true })
  end
end

local function apply_decorations(buf, decorations)
  vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
  for _, decoration in ipairs(decorations) do
    local column = 0
    for _, chunk in ipairs(decoration.chunks) do
      local text = chunk[1]
      if text ~= '' then
        vim.api.nvim_buf_set_extmark(buf, namespace, decoration.row, column, {
          end_col = column + #text,
          hl_group = chunk[2],
        })
      end
      column = column + #text
    end
  end
end

local function render_view(view_buf)
  local state = views[view_buf]
  if not state or not vim.api.nvim_buf_is_valid(state.source_buf) then
    return
  end

  generations[view_buf] = (generations[view_buf] or 0) + 1
  local generation = generations[view_buf]
  local width = vim.api.nvim_win_is_valid(state.win) and vim.api.nvim_win_get_width(state.win) - 1 or 79
  width = math.max(width, 20)
  local anchor
  if vim.api.nvim_win_is_valid(state.win) and vim.api.nvim_win_get_buf(state.win) == view_buf and state.source_map then
    anchor = source_cursor(state, vim.api.nvim_win_get_cursor(state.win))
  end
  renderer.render(state.source_buf, width, config.values, function(lines, decorations, source_map)
    if generation ~= generations[view_buf] or not vim.api.nvim_buf_is_valid(view_buf) then
      return
    end
    state = views[view_buf]
    if not state then
      return
    end
    vim.bo[view_buf].modifiable = true
    vim.api.nvim_buf_set_lines(view_buf, 0, -1, false, lines)
    vim.bo[view_buf].modifiable = false
    vim.bo[view_buf].readonly = true
    state.source_map = source_map
    apply_decorations(view_buf, decorations)
    refresh_markdown(state)
    local position = state.pending_source_cursor or anchor
    if position and vim.api.nvim_win_is_valid(state.win) and vim.api.nvim_win_get_buf(state.win) == view_buf then
      set_cursor(state.win, view_buf, view_cursor(state, position))
      state.pending_source_cursor = nil
    end
  end)
end

local function create_view(source_buf, mode)
  local source_name = vim.api.nvim_buf_get_name(source_buf)
  local source_win = vim.api.nvim_get_current_win()
  local initial_cursor = vim.api.nvim_win_get_cursor(source_win)
  local view_buf = vim.api.nvim_create_buf(false, true)
  pcall(vim.api.nvim_buf_set_name, view_buf, 'markdown-view://' .. source_name)
  vim.bo[view_buf].buftype = 'nofile'
  vim.bo[view_buf].bufhidden = 'hide'
  vim.bo[view_buf].swapfile = false
  vim.bo[view_buf].modifiable = true
  vim.api.nvim_buf_set_lines(view_buf, 0, -1, false, { 'Rendering Markdown view…' })
  vim.bo[view_buf].modifiable = false

  local win
  if mode == 'tab' then
    vim.cmd('tabnew')
    win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, view_buf)
  else
    win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, view_buf)
  end

  views[view_buf] = {
    view_buf = view_buf,
    source_buf = source_buf,
    source_win = source_win,
    win = win,
    mode = mode,
    last_source_cursor = initial_cursor,
    pending_source_cursor = initial_cursor,
  }
  source_views[source_buf] = view_buf

  vim.b[view_buf].markdown_view = true
  vim.bo[view_buf].filetype = 'markdown'
  vim.wo[win].wrap = false
  vim.wo[win].signcolumn = 'no'
  vim.wo[win].cursorline = false

  for _, key in ipairs(config.values.toggle_keys) do
    vim.keymap.set('n', key, function()
      show_source(view_buf)
    end, { buffer = view_buf, nowait = true })
  end
  vim.keymap.set('n', 'r', function()
    render_view(view_buf)
  end, { buffer = view_buf, nowait = true, desc = 'Refresh Markdown view' })
  vim.api.nvim_create_autocmd('BufWipeout', {
    group = group,
    buffer = view_buf,
    once = true,
    callback = function()
      cleanup_state(view_buf, views[view_buf])
    end,
  })
  views[view_buf].source_autocmd = vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    group = group,
    buffer = source_buf,
    callback = function()
      vim.defer_fn(function()
        if source_views[source_buf] == view_buf then
          render_view(view_buf)
        end
      end, config.values.refresh_delay_ms)
    end,
  })
  views[view_buf].source_wipe_autocmd = vim.api.nvim_create_autocmd('BufWipeout', {
    group = group,
    buffer = source_buf,
    once = true,
    callback = function()
      cleanup_state(view_buf, views[view_buf])
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(view_buf) then
          vim.api.nvim_buf_delete(view_buf, { force = true })
        end
      end)
    end,
  })

  render_view(view_buf)
  return view_buf
end

function M.open(buf, opts)
  if not buf or buf == 0 then
    buf = vim.api.nvim_get_current_buf()
  end
  if not eligible(buf) then
    return
  end
  local existing = source_views[buf]
  if existing and vim.api.nvim_buf_is_valid(existing) then
    local state = views[existing]
    if state and state.mode == 'replace' then
      state.win = vim.api.nvim_get_current_win()
      state.source_win = state.win
    end
    show_view(existing, vim.api.nvim_win_get_cursor(0))
    return existing
  end
  return create_view(buf, (opts or {}).mode or config.values.open_mode)
end

function M.toggle()
  local buf = vim.api.nvim_get_current_buf()
  if views[buf] then
    show_source(buf)
    return
  end
  M.open(buf)
end

function M.refresh()
  local buf = vim.api.nvim_get_current_buf()
  if views[buf] then
    render_view(buf)
  end
end

function M.close()
  close_view(vim.api.nvim_get_current_buf())
end

function M.setup(opts)
  config.setup(opts)
end

return M
