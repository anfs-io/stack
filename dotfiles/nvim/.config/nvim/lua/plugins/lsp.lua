
return {
  {
    'williamboman/mason.nvim',
    version = "v1.10.0", -- Pin to v1.x for compatibility
    config = function()
      require('mason').setup()
    end
  },
-- mason-lspconfig
  {
    'williamboman/mason-lspconfig.nvim',
    version = "v1.29.0", -- Pin to v1.x for compatibility
    dependencies = { 'williamboman/mason.nvim' },
    config = function()
      require('mason-lspconfig').setup {
        -- https://github.com/williamboman/mason-lspconfig.nvim#available-lsp-servers
        ensure_installed = { 'lua_ls', 'ruby_lsp', 'stimulus_ls', 'tailwindcss', 'ansiblels' },
        --[[
        'jinja_lsp'
        'angularls', 'bashls',
        'docker_compose_language_service', 'dockerls', 'elixirls', 'helm_ls', 'html'
        'rome' or 'biome' ? https://biomejs.dev/blog/annoucing-biome/
        'rubocop'
       -- ]]
        automatic_installation = true, -- This works in v1.x
      }
    end
  },
-- nvim-lspconfig
  {
    'neovim/nvim-lspconfig',
    dependencies = {'hrsh7th/cmp-nvim-lsp', 'hrsh7th/nvim-cmp', 'williamboman/mason-lspconfig.nvim'},
    lazy = false,
    config = function()
      local capabilities = require('cmp_nvim_lsp').default_capabilities()

      vim.lsp.config.lua_ls = {
        cmd = { 'lua-language-server' },
        settings = {
          Lua = {
            diagnostics = {
              globals = { 'vim' }, -- Get the language server to recognize the `vim` global
            }
          }
        }
      }

      vim.lsp.config.ruby_lsp = {
        cmd = { 'ruby-lsp' },
        capabilities = capabilities
      }

      vim.lsp.enable({'lua_ls', 'ruby_lsp'})

      vim.keymap.set('n', 'K', vim.lsp.buf.hover, {})
      vim.keymap.set('n', '<leader>gd', vim.lsp.buf.definition, {})
      vim.keymap.set('n', '<leader>gr', vim.lsp.buf.references, {})
      vim.keymap.set('n', '<leader>gf', vim.lsp.buf.format, {})
      vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, {})
      vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, {})
    end
  }
}
