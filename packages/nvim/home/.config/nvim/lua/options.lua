-- Basic Vim Settings
-- local opt = vim.opt
-- 
-- opt.number = true
-- opt.relativenumber = true
-- opt.mouse = "a"
-- opt.autoindent = true
-- opt.tabstop = 4
-- opt.softtabstop = 4
-- opt.shiftwidth = 4
-- opt.smarttab = true
-- opt.encoding = "utf-8"
-- opt.visualbell = true
-- opt.scrolloff = 5
-- opt.fillchars = { eob = " " }
-- 
-- if vim.fn.has("termguicolors") == 1 then
--   opt.termguicolors = true
-- end

vim.cmd("set expandtab")
vim.cmd("set tabstop=2")
vim.cmd("set softtabstop=2")
vim.cmd("set shiftwidth=2")
vim.g.mapleader = ","
vim.g.background = "light"

vim.opt.swapfile = false

-- Navigate vim panes better - REMOVED: handled by vim-tmux-navigator plugin
-- vim.keymap.set('n', '<c-k>', ':wincmd k<CR>')
-- vim.keymap.set('n', '<c-j>', ':wincmd j<CR>')
-- vim.keymap.set('n', '<c-h>', ':wincmd h<CR>')
-- vim.keymap.set('n', '<c-l>', ':wincmd l<CR>')
vim.keymap.set('n', '<leader>w', '<Esc>:w<cr><Space>')
vim.keymap.set('n', '<leader>wq', '<Esc>:wq<cr><Space>')
vim.keymap.set('n', '<leader>wqa', '<Esc>:wqa<cr><Space>')
vim.keymap.set('n', '<leader>qa', '<Esc>:q!<cr><Space>')

-- Emulate gt and gT vim tab navigation but with documents
-- Targeting markdown docs. The obsidian plugin is configured with gf to follow link
vim.keymap.set('n', 'gF', ':bprevious<CR>')
-- vim.keymap.set('n', 'gF', '<C-o>', { desc = 'Go back in jump list' })

vim.wo.number = true
vim.wo.relativenumber = true

vim.opt.conceallevel = 1


-- t(mux)y(yank) Yank the default register to tmux buffer
vim.keymap.set('n', '<leader>ty', function()
  vim.fn.system('tmux load-buffer -', vim.fn.getreg('"'))
end, { desc = 'Copy register to tmux' })

-- t(tmux)p(aste) - Paste from tmux buffer
vim.keymap.set('n', '<leader>tp', ':read !tmux show-buffer<CR>', { desc = 'Paste tmux buffer' })

-- For obsidian bases uses .base file extension
vim.filetype.add({
  extension = {
    base = 'yaml',
  }
})

-- Disable LSP warnings
vim.lsp.set_log_level("off")

-- Jump to the NEXT warning/error using 'gw'
-- vim.keymap.set('n', 'gw', vim.diagnostic.goto_next, { desc = "Go to next diagnostic" })

-- Jump to the PREVIOUS warning/error using 'gW' (shift + w)
-- vim.keymap.set('n', 'gW', vim.diagnostic.goto_prev, { desc = "Go to previous diagnostic" })

-- -- Automatically show diagnostics in a floating window on hover
-- vim.api.nvim_create_autocmd("CursorHold", {
--   -- buffer = bufnr,
--   callback = function()
--     vim.diagnostic.open_float(nil, { focusable = false })
--   end,
-- })
--
-- -- Speed up the hover delay (default is 4000ms/4 seconds, change to 400ms)
-- vim.o.updatetime = 400
--


-- Helper function to open and focus the diagnostic window (with optional jumping)
local function focus_diagnostic(direction_func)
  -- 1. If a jump function was passed, execute it first
  if direction_func then
    direction_func({ float = false })
  end

  -- 2. Schedule the focused popup to open
  vim.schedule(function()
    local _, winnr = vim.diagnostic.open_float(nil, { focusable = true })
    if winnr then
      vim.api.nvim_set_current_win(winnr)
    end
  end)
end

-- Map 'gl' to view the warning on the CURRENT line
vim.keymap.set('n', 'gl', function()
  focus_diagnostic() -- No argument passed, so it just opens right here
end, { desc = "Show line diagnostic and focus" })

-- Map 'gw' for NEXT warning
vim.keymap.set('n', 'gw', function()
  focus_diagnostic(vim.diagnostic.goto_next)
end, { desc = "Jump to next diagnostic and focus popup" })

-- Map 'gW' for PREVIOUS warning
vim.keymap.set('n', 'gW', function()
  focus_diagnostic(vim.diagnostic.goto_prev)
end, { desc = "Jump to previous diagnostic and focus popup" })
