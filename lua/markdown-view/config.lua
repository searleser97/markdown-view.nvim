local M = {}

M.defaults = {
  enabled = true,
  open_mode = 'replace',
  auto_open = false,
  auto_open_delay_ms = 100,
  file_types = { 'markdown' },
  refresh_delay_ms = 200,
  render_tables = true,
  render_mermaid = true,
  tables = {
    highlights = {
      border = 'MarkdownViewTableBorder',
      header = 'MarkdownViewTableHeader',
      row = 'MarkdownViewTableRow',
    },
  },
  mermaid = {
    cmd = { 'termaid' },
    highlights = {
      diagram = 'DiagnosticInfo',
      legend = 'DiagnosticInfo',
    },
    shorten_labels = false,
    shorten_labels_hints = true,
  },
}

M.values = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.values = vim.tbl_deep_extend('force', vim.deepcopy(M.defaults), opts or {})
  return M.values
end

return M
