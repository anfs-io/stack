vim.filetype.add({
  filename = {
    [".pryrc"] = "ruby",
  },
  pattern = {
    [".*/pry/pryrc"] = "ruby",
  },
})
