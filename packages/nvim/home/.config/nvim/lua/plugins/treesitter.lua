 -- https://typecraft.dev/neovim-for-newbs/sitting-in-a-tree-with-treesitter
return {
  -- The build argument tells nvim to run the command :TSUpdate which will update treesitter itself
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  config = function()
    local config = require("nvim-treesitter.configs")
    config.setup({
      -- https://github.com/nvim-treesitter/nvim-treesitter?tab=readme-ov-file#supported-languages
      ensure_installed = { "css", "csv", "dockerfile", "hcl", "html", "javascript", "json", "lua", "markdown", "mermaid", "ruby", 'ssh_config', "solidity", "sql", "terraform", "tmux", "toml", 'typescript', "yaml" },
      highlight = { enable = true },
      indent = { enable = true }
    })
  end
}
