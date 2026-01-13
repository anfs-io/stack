return {
  {
    'williamboman/mason.nvim',
    version = "v2.0.1",
    config = function()
      require('mason').setup()
    end,
  },
  {
    'williamboman/mason-lspconfig.nvim',
    version = "v2.1.0",
    dependencies = { 'williamboman/mason.nvim' },
    config = function()
      -- Dynamically load all LSP configs
      local servers = {}
      local lsp_dir = vim.fn.stdpath('config') .. '/lua/plugins/lsp'
      local files = vim.fn.globpath(lsp_dir, '*.lua', false, true)

      for _, file in ipairs(files) do
        local name = vim.fn.fnamemodify(file, ':t:r')
        local ok, config = pcall(require, 'plugins.lsp.' .. name)
        if ok and type(config) == 'table' then
          servers = vim.tbl_extend('force', servers, config)
        end
      end

      require('mason-lspconfig').setup({
        ensure_installed = vim.tbl_keys(servers),
        automatic_installation = true,
        automatic_enable = false,
      })
    end,
  },
  {
    'neovim/nvim-lspconfig',
    dependencies = {
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/nvim-cmp',
      'williamboman/mason-lspconfig.nvim',
    },
    lazy = false,
    config = function()
      local capabilities = require('cmp_nvim_lsp').default_capabilities()

      -- Load and configure all servers
      local servers = {}
      local lsp_dir = vim.fn.stdpath('config') .. '/lua/plugins/lsp'
      local files = vim.fn.globpath(lsp_dir, '*.lua', false, true)

      for _, file in ipairs(files) do
        local name = vim.fn.fnamemodify(file, ':t:r')
        local ok, config = pcall(require, 'plugins.lsp.' .. name)
        if ok and type(config) == 'table' then
          servers = vim.tbl_extend('force', servers, config)
        end
      end

      for server, opts in pairs(servers) do
        opts.capabilities = opts.capabilities or capabilities
        vim.lsp.config[server] = opts
      end

      vim.lsp.enable(vim.tbl_keys(servers))

      -- Keymaps
      vim.keymap.set('n', 'K', vim.lsp.buf.hover, {})
      vim.keymap.set('n', '<leader>gd', vim.lsp.buf.definition, {})
      vim.keymap.set('n', '<leader>gr', vim.lsp.buf.references, {})
      vim.keymap.set('n', '<leader>gf', vim.lsp.buf.format, {})
      vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, {})
      vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, {})
    end,
  },
}
