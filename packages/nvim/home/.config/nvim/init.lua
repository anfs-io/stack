
-- Clone the Lazy package manager if it doesn't exist locally; should be found in ~/.local/share/nvim/lazy
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("options")
require("lazy").setup("plugins")

-- Automatically require all Lua files/symlinks in the lua/filetypes/ directory
local filetypes_dir = vim.fn.stdpath("config") .. "/lua/filetypes"
local handle = vim.loop.fs_scandir(filetypes_dir)

if handle then
  while true do
    local name, type = vim.loop.fs_scandir_next(handle)
    if not name then break end

    -- Accept BOTH regular files and symlinks that end in .lua
    if (type == "file" or type == "link") and name:match("%.lua$") then
      local module_name = name:sub(1, -5) -- strip ".lua"
      require("filetypes." .. module_name)
    end
  end
end
