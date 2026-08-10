local M = {}

M.defaults = {
  enabled = true,
  open_mode = 'replace',
  file_types = { 'markdown' },
  refresh_delay_ms = 200,
  render_tables = true,
  render_mermaid = true,
  toggle_keys = { 'q', '<Esc>', 'e' },
  tables = {
    highlights = {
      border = 'MarkdownViewTableBorder',
      header = 'MarkdownViewTableHeader',
      row = 'MarkdownViewTableRow',
    },
  },
  mermaid = {
    cmd = { 'termaid' },
    highlight = 'DiagnosticInfo',
    legend_highlight = 'DiagnosticInfo',
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
