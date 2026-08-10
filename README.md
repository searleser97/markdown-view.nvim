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
    'MeanderingProgrammer/render-markdown.nvim',
  },
  ft = { 'markdown' },
  opts = {},
}
```

## Configuration

```lua
require('markdown-view').setup({
  open_mode = 'replace', -- 'replace' or 'tab'
  refresh_delay_ms = 200,
  render_tables = true,
  render_mermaid = true,
})
```

## Commands

| Command | Description |
| --- | --- |
| `:MarkdownView` | Replace the current window with a rendered view |
| `:MarkdownViewToggle` | Toggle between source and rendered view |
| `:MarkdownViewTab` | Open a rendered view in a new tab |
| `:MarkdownViewRefresh` | Refresh the current rendered view |
| `:MarkdownViewClose` | Close the view and return to the source |

Inside a rendered view:

- `q`, `Esc`, or `e` toggles back to the source while retaining the view.
- `r` refreshes the rendered content.

To keep source buffers completely raw while rendering only generated views:

```lua
require('render-markdown').setup({ enabled = false })
require('mermaid-nvim').setup({ enabled = false })
require('markdown-table').setup({ enabled = false })
```

`markdown-view.nvim` enables `render-markdown.nvim` only for its generated
buffer and directly uses the table and Mermaid renderers.
