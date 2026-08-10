local M = {}

local function flatten(chunks)
  local result = ''
  for _, chunk in ipairs(chunks) do
    result = result .. chunk[1]
  end
  return result
end

local function table_replacements(buf, width, overrides)
  local table_config = vim.tbl_deep_extend(
    'force',
    vim.deepcopy(require('markdown-table.config').defaults),
    overrides or {}
  )
  table_config.max_width = width
  local renderer = require('markdown-table.renderer')
  local result = {}

  for _, item in ipairs(require('markdown-table.parser').tables(buf)) do
    local rendered = renderer.lines(buf, item, table_config)
    result[#result + 1] = {
      start_row = item.start_row,
      end_row = item.end_row,
      lines = vim.tbl_map(flatten, rendered),
      chunks = rendered,
    }
  end
  return result
end

local function mermaid_replacement(block, mermaid_config, callback)
  require('mermaid-nvim.renderer').render_text(block.source, mermaid_config, function(result)
    if result.error then
      local message = tostring(result.error):gsub('\n', ' '):sub(1, 120)
      callback({
        start_row = block.start_row,
        end_row = block.end_row,
        lines = { '⚠ Mermaid render error: ' .. message },
        chunks = { { { '⚠ Mermaid render error: ' .. message, 'DiagnosticError' } } },
      })
      return
    end
    callback({
      start_row = block.start_row,
      end_row = block.end_row,
      lines = result.lines,
      chunks = result.chunks,
    })
  end)
end

local function merge(source_lines, replacements)
  table.sort(replacements, function(left, right)
    return left.start_row < right.start_row
  end)

  local lines = {}
  local decorations = {}
  local source_map = {}
  local source_row = 0

  for _, replacement in ipairs(replacements) do
    while source_row < replacement.start_row do
      lines[#lines + 1] = source_lines[source_row + 1]
      source_map[#lines] = source_row + 1
      source_row = source_row + 1
    end
    local output_start = #lines
    for index, line in ipairs(replacement.lines) do
      lines[#lines + 1] = line
      local output_span = math.max(#replacement.lines - 1, 1)
      local source_span = replacement.end_row - replacement.start_row
      source_map[#lines] = replacement.start_row
        + math.floor(((index - 1) * source_span / output_span) + 0.5)
        + 1
      decorations[#decorations + 1] = {
        row = output_start + index - 1,
        chunks = replacement.chunks[index],
      }
    end
    source_row = replacement.end_row + 1
  end

  while source_row < #source_lines do
    lines[#lines + 1] = source_lines[source_row + 1]
    source_map[#lines] = source_row + 1
    source_row = source_row + 1
  end

  return lines, decorations, source_map
end

function M.render(buf, width, opts, callback)
  local source_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local replacements = opts.render_tables and table_replacements(buf, width, opts.tables) or {}
  local blocks = opts.render_mermaid and require('mermaid-nvim.scanner').find_blocks(buf) or {}

  if #blocks == 0 then
    callback(merge(source_lines, replacements))
    return
  end

  local remaining = #blocks
  for _, block in ipairs(blocks) do
    mermaid_replacement(block, opts.mermaid, function(replacement)
      replacements[#replacements + 1] = replacement
      remaining = remaining - 1
      if remaining == 0 then
        callback(merge(source_lines, replacements))
      end
    end)
  end
end

return M
