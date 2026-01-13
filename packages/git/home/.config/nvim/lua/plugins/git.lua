return {
  'lewis6991/gitsigns.nvim',
  config = function()
    require("gitsigns").setup()

    vim.keymap.set("n", "<leader>gs", ":Gitsigns preview_hunk_inline<CR>", {})
    vim.keymap.set("n", "<leader>gb", ":Gitsigns toggle_current_line_blame<CR>", {})
    vim.keymap.set("n", "<leader>gst", ":Git status<CR>", {})
    vim.keymap.set("n", "<leader>glg", ":Git log --stat<CR>", {})
    vim.keymap.set("n", "<leader>ga", ":Git add .<CR>", {})
    vim.keymap.set("n", "<leader>gc", ":Git commit<CR>", {})
    vim.keymap.set("n", "<leader>gdf", ":Git diff<CR>", {})
    vim.keymap.set("n", "<leader>gp", ":Git push<CR>", {})
  end
}
