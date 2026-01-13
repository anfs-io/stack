return {
  lua_ls = {
    cmd = { 'lua-language-server' },
    settings = {
      Lua = {
        diagnostics = {
          globals = { 'vim' },
        },
      },
    },
  },
}
