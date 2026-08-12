# markdown-view.nvim

Toggle between Markdown source and a read-only rendered document with formatted
tables and Mermaid diagrams integrated into the document flow. Cursor position
is preserved in both directions.

## Requirements

- Neovim 0.11+
- `searleser97/markdown-table.nvim`
- `searleser97/mermaid-nvim`
- `MeanderingProgrammer/render-markdown.nvim`

## Installation

```lua
{
  'searleser97/markdown-view.nvim',
  dependencies = {
    'searleser97/markdown-table.nvim',
    'searleser97/mermaid-nvim',
    {
      'MeanderingProgrammer/render-markdown.nvim',
      dependencies = {
        'nvim-treesitter/nvim-treesitter',
        'nvim-tree/nvim-web-devicons',
      },
      opts = {
        enabled = false,
        pipe_table = { enabled = false },
        code = { disable = { 'mermaid' } },
      },
    },
  },
  ft = { 'markdown' },
  opts = {},
}
```

## Configuration

```lua
require('markdown-view').setup({
  open_mode = 'replace', -- 'replace' or 'tab'
  auto_open = false,
  auto_open_delay_ms = 100,
  refresh_delay_ms = 200,
  render_tables = true,
  render_mermaid = true,
  tables = {
    padding = 1,
    min_column_width = 3,
    max_column_width = 40,
  },
  mermaid = {
    cmd = { 'termaid', '--padding-x', '2', '--padding-y', '0' },
    highlights = {
      diagram = 'DiagnosticInfo',
      legend = 'DiagnosticInfo',
    },
    shorten_labels = false,
  },
})
```

The `tables` and `mermaid` options are local to generated Markdown view buffers.
They do not read or modify the active configuration of either dependency.

When `auto_open` is enabled, regular Markdown files open in rendered view after
`auto_open_delay_ms`. Generated, unnamed, and non-file buffers are ignored.

## Commands

| Command | Description |
| --- | --- |
| `:MarkdownView` | Replace the current window with a rendered view |
| `:MarkdownViewToggle` | Toggle between source and rendered view |
| `:MarkdownViewTab` | Open a rendered view in a new tab |
| `:MarkdownViewRefresh` | Refresh the current rendered view |
| `:MarkdownViewClose` | Close the view and return to the source |

## Lua API

- `require('markdown-view').open(buf)` opens the rendered view for a source buffer.
- `require('markdown-view').edit(buf)` returns a rendered view buffer to its source.
- `require('markdown-view').refresh()` refreshes the current rendered view.
- `require('markdown-view').close()` closes the current rendered view.

The plugin does not define key mappings. Configure mappings and automatic
view/edit transitions in your Neovim configuration using the Lua API.

`markdown-view.nvim` enables `render-markdown.nvim` only for its generated
buffer and directly uses the table and Mermaid rendering modules. The table and
Mermaid dependencies do not need to be configured unless they are also used
independently in source buffers.
