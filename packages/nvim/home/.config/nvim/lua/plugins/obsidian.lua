-- https://github.com/epwalsh/obsidian.nvim?tab=readme-ov-file
return {
  "epwalsh/obsidian.nvim",
  version = "*",  -- recommended, use latest release instead of latest commit
  lazy = true,
  ft = "markdown",
  -- Replace the above line with this if you only want to load obsidian.nvim for markdown files in your vault:
  -- event = {
  --   -- If you want to use the home shortcut '~' here you need to call 'vim.fn.expand'.
  --   -- E.g. "BufReadPre " .. vim.fn.expand "~" .. "/my-vault/*.md"
  --   -- refer to `:h file-pattern` for more examples
  --   "BufReadPre path/to/my-vault/*.md",
  --   "BufNewFile path/to/my-vault/*.md",
  -- },
  dependencies = {
    "nvim-lua/plenary.nvim", -- Required.
    -- see below for full list of optional dependencies 👇
  },
  opts = {
    workspaces = {
      {
        name = "code",
        path = "$CODE_DIR",
      },
    },
    -- open internet URL
    follow_url_func = function(url)
    local cmd
    if vim.fn.has("mac") == 1 then
      cmd = {"open", url}
    elseif vim.fn.has("unix") == 1 then
      cmd = {"xdg-open", url}
    elseif vim.fn.has("win32") == 1 then
      cmd = {"cmd", "/c", "start", url}
    else
      vim.notify("Don't know how to open URL on this OS", vim.log.levels.ERROR)
      return
    end

    vim.fn.jobstart(cmd, {detach = true})
    end,
    -- see below for full list of options 👇
  },
  mappings = {
    -- Overrides the 'gf' mapping to work on markdown/wiki links within your vault.
    ["gf"] = {
      action = function()
        return require("obsidian").util.gf_passthrough()
      end,
      opts = { noremap = false, expr = true, buffer = true },
    },
    -- Go back in jump list - obsidian specific
    -- ["gF"] = {
    --   action = function()
    --     vim.cmd("normal! \15") -- \15 is <C-o>
    --   end,
    --   opts = { buffer = true },
    -- },
    -- Toggle check-boxes.
    ["<leader>ch"] = {
      action = function()
        return require("obsidian").util.toggle_checkbox()
      end,
      opts = { buffer = true },
    },
  },
}
