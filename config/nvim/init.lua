-- devbox Neovim config: no plugin manager, built-in LSP (Neovim 0.11+).
-- YAML gets yaml-language-server (schemas, hover, completion, diagnostics,
-- and formatting via its bundled prettier). yamllint is available on the CLI.

-- ---------------------------------------------------------------------------
-- Options
-- ---------------------------------------------------------------------------
vim.g.mapleader = ' '
vim.o.number = true
vim.o.signcolumn = 'yes'
vim.o.termguicolors = true
vim.o.mouse = 'a'
vim.o.expandtab = true
vim.o.shiftwidth = 2
vim.o.tabstop = 2
vim.o.smartindent = true
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.updatetime = 300
vim.o.undofile = true
vim.o.list = true
vim.opt.listchars = { tab = '→ ', trail = '·', nbsp = '␣' }
vim.o.clipboard = 'unnamedplus'  -- works through tmux set-clipboard / OSC 52

-- YAML: two-space indent, never tabs, fold on indent
vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'yaml', 'yaml.docker-compose' },
  callback = function()
    vim.bo.expandtab = true
    vim.bo.shiftwidth = 2
    vim.bo.tabstop = 2
    vim.wo.foldmethod = 'indent'
    vim.wo.foldlevel = 99
  end,
})

-- ---------------------------------------------------------------------------
-- LSP: yaml-language-server
-- ---------------------------------------------------------------------------
vim.lsp.config('yamlls', {
  cmd = { 'yaml-language-server', '--stdio' },
  filetypes = { 'yaml', 'yaml.docker-compose', 'yaml.gitlab' },
  root_markers = { '.git', 'kustomization.yaml', 'Chart.yaml' },
  settings = {
    redhat = { telemetry = { enabled = false } },
    yaml = {
      validate = true,
      hover = true,
      completion = true,
      keyOrdering = false,
      format = {
        enable = true,
        singleQuote = false,
        bracketSpacing = true,
        proseWrap = 'preserve',
        printWidth = 120,
      },
      -- Pull schemas for docker-compose, GitHub Actions, Helm, Taskfile, etc.
      schemaStore = {
        enable = true,
        url = 'https://www.schemastore.org/api/json/catalog.json',
      },
      -- Kubernetes schema for manifest-style paths. Adjust globs to taste.
      schemas = {
        kubernetes = {
          'k8s/**/*.yaml', 'k8s/**/*.yml',
          'kubernetes/**/*.yaml', 'kubernetes/**/*.yml',
          'manifests/**/*.yaml', 'manifests/**/*.yml',
          'clusters/**/*.yaml', 'apps/**/*.yaml', 'infrastructure/**/*.yaml',
          '*.k8s.yaml', 'talos/**/*.yaml',
        },
      },
    },
  },
})
vim.lsp.enable('yamlls')

-- ---------------------------------------------------------------------------
-- Diagnostics + keymaps
-- ---------------------------------------------------------------------------
vim.diagnostic.config({
  virtual_text = { spacing = 2, prefix = '●' },
  severity_sort = true,
  float = { border = 'rounded', source = true },
})

local map = vim.keymap.set
map('n', '<leader>f', function() vim.lsp.buf.format({ async = true }) end, { desc = 'Format buffer' })
map('n', '<leader>e', vim.diagnostic.open_float, { desc = 'Line diagnostics' })
map('n', '[d', function() vim.diagnostic.jump({ count = -1 }) end, { desc = 'Prev diagnostic' })
map('n', ']d', function() vim.diagnostic.jump({ count = 1 }) end, { desc = 'Next diagnostic' })
map('n', 'K', vim.lsp.buf.hover, { desc = 'Hover' })
map('n', 'gd', vim.lsp.buf.definition, { desc = 'Go to definition' })
map('n', '<leader>rn', vim.lsp.buf.rename, { desc = 'Rename' })
map('n', '<leader>ca', vim.lsp.buf.code_action, { desc = 'Code action' })
map('n', '<leader>w', '<cmd>write<cr>', { desc = 'Save' })
map('n', '<leader>q', '<cmd>quit<cr>', { desc = 'Quit' })
map('n', '<Esc>', '<cmd>nohlsearch<cr>')

-- Format YAML on save through the LSP
vim.api.nvim_create_autocmd('BufWritePre', {
  pattern = { '*.yaml', '*.yml' },
  callback = function(args)
    vim.lsp.buf.format({ bufnr = args.buf, timeout_ms = 3000 })
  end,
})

-- Completion popup as you type (built-in, Neovim 0.11+)
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if client and client:supports_method('textDocument/completion') then
      vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true })
    end
  end,
})
