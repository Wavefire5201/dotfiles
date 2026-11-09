-- Path-scoped "plain text" overrides for notes directories (see config/notes.lua).
-- Markdown everywhere else keeps the LazyVim markdown extra.
local notes = require("config.notes")

return {
  -- Don't render markdown inside notes directories.
  {
    "MeanderingProgrammer/render-markdown.nvim",
    optional = true,
    opts = function(_, opts)
      local prev = opts.ignore
      opts.ignore = function(buf)
        return notes.is_notes_buf(buf) or (prev ~= nil and prev(buf) == true)
      end
    end,
  },

  -- Detach marksman from notes buffers only (keep it for markdown elsewhere).
  {
    "neovim/nvim-lspconfig",
    optional = true,
    init = function()
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("notes_lsp", { clear = true }),
        callback = function(ev)
          local client = vim.lsp.get_client_by_id(ev.data.client_id)
          if client and client.name == "marksman" and notes.is_notes_buf(ev.buf) then
            vim.lsp.buf_detach_client(ev.buf, client.id)
          end
        end,
      })
    end,
  },

  -- Skip markdownlint (from the markdown extra) inside notes directories.
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = function(_, opts)
      opts.linters = opts.linters or {}
      local existing = opts.linters["markdownlint-cli2"] or {}
      local prev = existing.condition
      opts.linters["markdownlint-cli2"] = vim.tbl_deep_extend("force", existing, {
        condition = function(ctx)
          if notes.is_notes(ctx.filename) then
            return false
          end
          return prev == nil or prev(ctx) == true
        end,
      })
    end,
  },
}
