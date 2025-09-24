-- https://typecraft.dev/neovim-for-newbs/fuzzy-finding-with-a-telescope
return {
  'nvim-telescope/telescope.nvim',
  tag = '0.1.8',
  dependencies = { 'nvim-lua/plenary.nvim', 'nvim-telescope/telescope-ui-select.nvim', },
  config = function()
    require('telescope').setup({
      pickers = {
        find_files = {
          hidden = true,
          theme = 'ivy',
        }
      },
      extensions = {
        ['ui-select'] = {
          require('telescope.themes').get_dropdown({}),
        }
      }
    })
    require('telescope').load_extension('ui-select')
    -- Set a local variable `builtin` so we can use it to call functions that the module exposes
    local builtin = require('telescope.builtin')

    vim.keymap.set('n', '<leader>bb', ':Telescope buffers<CR>')
    vim.keymap.set('n', '<C-p>', builtin.find_files, {})
    vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
    vim.keymap.set('n', '<leader><leader>', builtin.oldfiles, {})
  end
}

