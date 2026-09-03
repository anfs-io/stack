-- ruby_lsp configuration.
--
-- Engine gotcha: ruby-lsp-rails' RunnerClient boots the app by running
-- `bundle exec rails runner server.rb` from the language server's *current
-- working directory* (it checks `File.exist?("bin/rails")` relative to cwd and
-- reads the Rails root back from the booted app). In a Rails *engine*, the
-- runnable app lives in spec/dummy (or test/dummy), and the engine root's
-- bin/rails uses `rails/engine/commands`, which does not boot a full app the
-- way the addon needs. The result: the addon can't introspect the app, so
-- `app/**` (models, controllers, incl. namespaced ones) never gets indexed,
-- while `lib/**` still resolves via ordinary gem indexing.
--
-- Fix: when the project root looks like an engine, spawn ruby-lsp with its cwd
-- set to the dummy app. For a normal app (no dummy), cwd stays at the root, so
-- this is a no-op there.

local uv = vim.uv or vim.loop

-- Given a project root, return the directory the language server should run in.
-- Engine  -> <root>/spec/dummy or <root>/test/dummy (whichever has config/application.rb)
-- Normal  -> <root> unchanged (returns nil to signal "no override")
local function dummy_app_dir(root)
  if not root then
    return nil
  end
  for _, sub in ipairs({ '/spec/dummy', '/test/dummy' }) do
    local candidate = root .. sub
    if uv.fs_stat(candidate .. '/config/application.rb') then
      return candidate
    end
  end
  return nil
end

-- Resolve the project root the same way lspconfig would: nearest ancestor of
-- the current buffer containing a Gemfile (falling back to .git).
local function project_root()
  local bufname = vim.api.nvim_buf_get_name(0)
  local start = (bufname ~= '' and vim.fs.dirname(bufname)) or uv.cwd()
  local found = vim.fs.find({ 'Gemfile', '.git' }, { path = start, upward = true })[1]
  if found then
    return vim.fs.dirname(found)
  end
  return uv.cwd()
end

return {
  ruby_lsp = {
    -- `cmd` as a function lets us set the spawn `cwd` per-project. The new
    -- vim.lsp API invokes it as cmd(dispatchers, config) and uses the returned
    -- rpc client; passing `cwd` in the opts controls the server's working dir.
    cmd = function(dispatchers, config)
      local root = (config and config.root_dir) or project_root()
      local cwd = dummy_app_dir(root) or root
      return vim.lsp.rpc.start({ 'ruby-lsp' }, dispatchers, { cwd = cwd })
    end,

    -- Keep the language server rooted at the engine/app root for buffer
    -- attachment and workspace purposes, even though it *runs* in the dummy.
    root_dir = function(bufnr, on_dir)
      local bufname = vim.api.nvim_buf_get_name(bufnr)
      local start = (bufname ~= '' and vim.fs.dirname(bufname)) or uv.cwd()
      local found = vim.fs.find({ 'Gemfile', '.git' }, { path = start, upward = true })[1]
      on_dir(found and vim.fs.dirname(found) or uv.cwd())
    end,

    -- ruby-lsp replies to semantic-token requests even after nvim cancels them
    -- (it doesn't honor $/cancelRequest for semanticTokens), producing the noisy
    -- `NO_RESULT_CALLBACK_FOUND` log lines. Turn the feature off so nvim never
    -- issues those requests.
    on_attach = function(client, _bufnr)
      client.server_capabilities.semanticTokensProvider = nil
    end,
  },
  -- rubocop = {},  -- uncomment when ready
}
