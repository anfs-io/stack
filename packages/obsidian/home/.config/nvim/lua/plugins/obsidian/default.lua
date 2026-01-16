-- Default Obsidian.nvim configuration
return {
  workspaces = {
    {
      name = "home",
      path = "$HOME",
    },
  },
  
  -- Disable frontmatter management by default
  -- Set to false if you want automatic id/aliases/tags added
  disable_frontmatter = true,
  
  -- Optional: specify patterns where frontmatter SHOULD be managed
  -- frontmatter_include_patterns = {
  --   "/inbox/",
  --   "/quick%-notes/",
  -- },
  
  mappings = {
    -- Follow links (wiki-links and markdown links) with smart passthrough
    ["gf"] = {
      action = function()
        return require("obsidian").util.gf_passthrough()
      end,
      opts = { noremap = false, expr = true, buffer = true },
    },
    
    -- Toggle checkboxes in tasks
    ["<leader>ch"] = {
      action = function()
        return require("obsidian").util.toggle_checkbox()
      end,
      opts = { buffer = true },
    },
  },
}
