if vim.g.loaded_markdown_view_nvim then
  return
end
vim.g.loaded_markdown_view_nvim = true

vim.api.nvim_create_user_command('MarkdownView', function()
  require('markdown-view').open(0)
end, { desc = 'Open a rendered Markdown view' })

vim.api.nvim_create_user_command('MarkdownViewToggle', function()
  require('markdown-view').toggle()
end, { desc = 'Toggle between Markdown source and rendered view' })

vim.api.nvim_create_user_command('MarkdownViewTab', function()
  require('markdown-view').open(0, { mode = 'tab' })
end, { desc = 'Open a rendered Markdown view in a new tab' })

vim.api.nvim_create_user_command('MarkdownViewRefresh', function()
  require('markdown-view').refresh()
end, { desc = 'Refresh the current rendered Markdown view' })

vim.api.nvim_create_user_command('MarkdownViewClose', function()
  require('markdown-view').close()
end, { desc = 'Close the current rendered Markdown view' })
