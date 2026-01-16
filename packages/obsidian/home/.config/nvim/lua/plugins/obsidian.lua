-- https://github.com/epwalsh/obsidian.nvim
-- Main loader for obsidian.nvim - loads configurations from lua/plugins/obsidian/*.lua

-- Load obsidian-specific configurations from other packages
local function load_obsidian_configs()
  local configs = {}
  local config_dir = vim.fn.stdpath("config") .. "/lua/plugins/obsidian"

  -- Check if the obsidian config directory exists
  if vim.fn.isdirectory(config_dir) == 1 then
    -- Load all lua files from the obsidian config directory
    for _, file in ipairs(vim.fn.readdir(config_dir)) do
      if file:match("%.lua$") then
        local module_name = file:gsub("%.lua$", "")
        local ok, config = pcall(require, "plugins.obsidian." .. module_name)
        if ok and type(config) == "table" then
          table.insert(configs, config)
        end
      end
    end
  end
  
  return configs
end

-- Merge workspace configurations
local function merge_workspaces(configs)
  local workspaces = {}
  
  for _, config in ipairs(configs) do
    if config.workspaces then
      for _, workspace in ipairs(config.workspaces) do
        table.insert(workspaces, workspace)
      end
    end
  end
  
  return workspaces
end

-- Check if frontmatter management should be disabled globally
local function should_disable_frontmatter(configs)
  for _, config in ipairs(configs) do
    if config.disable_frontmatter ~= nil then
      return config.disable_frontmatter
    end
  end
  return false
end

-- Merge frontmatter functions
local function create_frontmatter_func(configs)
  -- Check if frontmatter is globally disabled
  if should_disable_frontmatter(configs) then
    return function(note)
      -- Return existing metadata unchanged
      return note.metadata or {}
    end
  end
  
  -- Collect include patterns (for enabling frontmatter in specific dirs)
  local include_patterns = {}
  
  for _, config in ipairs(configs) do
    if config.frontmatter_include_patterns then
      for _, pattern in ipairs(config.frontmatter_include_patterns) do
        table.insert(include_patterns, pattern)
      end
    end
  end
  
  return function(note)
    local note_path = tostring(note.path)
    
    -- If no include patterns are specified, don't add frontmatter
    if #include_patterns == 0 then
      return note.metadata or {}
    end
    
    -- Check if note matches any include pattern
    local should_manage = false
    for _, pattern in ipairs(include_patterns) do
      if note_path:match(pattern) then
        should_manage = true
        break
      end
    end
    
    if not should_manage then
      -- Return existing metadata unchanged
      return note.metadata or {}
    end
    
    -- Apply frontmatter management for included paths
    local out = { 
      id = note.id, 
      aliases = note.aliases, 
      tags = note.tags 
    }
    
    if note.metadata ~= nil and not vim.tbl_isempty(note.metadata) then
      for k, v in pairs(note.metadata) do
        out[k] = v
      end
    end
    
    return out
  end
end

-- Merge custom mappings
local function merge_mappings(configs)
  local mappings = {}
  
  -- Merge mappings from all configs
  for _, config in ipairs(configs) do
    if config.mappings then
      for key, mapping in pairs(config.mappings) do
        mappings[key] = mapping
      end
    end
  end
  
  return mappings
end

-- Load all configs
local obsidian_configs = load_obsidian_configs()

return {
  "epwalsh/obsidian.nvim",
  version = "*",
  lazy = true,
  ft = "markdown",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  opts = {
    workspaces = merge_workspaces(obsidian_configs),
    note_frontmatter_func = create_frontmatter_func(obsidian_configs),
    
    -- Open internet URLs
    follow_url_func = function(url)
      local cmd
      if vim.fn.has("mac") == 1 then
        cmd = {"open", url}
      elseif vim.fn.has("unix") == 1 then
        cmd = {"xdg-open", url}
      elseif vm.fn.has("win32") == 1 then
        cmd = {"cmd", "/c", "start", url}
      else
        vim.notify("Don't know how to open URL on this OS", vim.log.levels.ERROR)
        return
      end

      vim.fn.jobstart(cmd, {detach = true})
    end,
  },
  mappings = merge_mappings(obsidian_configs),
}
