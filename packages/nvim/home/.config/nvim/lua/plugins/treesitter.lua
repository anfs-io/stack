-- https://github.com/nvim-treesitter/nvim-treesitter
-- Main loader for nvim-treesitter - loads configurations from lua/plugins/treesitter/*.lua

-- Load treesitter-specific configurations from other packages
local function load_treesitter_configs()
  local configs = {}
  local config_dir = vim.fn.stdpath("config") .. "/lua/plugins/treesitter"

  -- Check if the treesitter config directory exists
  if vim.fn.isdirectory(config_dir) == 1 then
    -- Load all lua files from the treesitter config directory
    for _, file in ipairs(vim.fn.readdir(config_dir)) do
      if file:match("%.lua$") then
        local module_name = file:gsub("%.lua$", "")
        local ok, config = pcall(require, "plugins.treesitter." .. module_name)
        if ok and type(config) == "table" then
          table.insert(configs, config)
        end
      end
    end
  end

  return configs
end

-- Merge ensure_installed parsers from all configs
local function merge_ensure_installed(configs)
  local parsers = {}
  local seen = {}

  for _, config in ipairs(configs) do
    if config.ensure_installed then
      for _, parser in ipairs(config.ensure_installed) do
        if not seen[parser] then
          seen[parser] = true
          table.insert(parsers, parser)
        end
      end
    end
  end

  -- Sort for consistent ordering
  table.sort(parsers)
  return parsers
end

-- Load all configs
local treesitter_configs = load_treesitter_configs()

return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  config = function()
    require("nvim-treesitter").setup({
      ensure_installed = merge_ensure_installed(treesitter_configs),
    })
  end,
}
