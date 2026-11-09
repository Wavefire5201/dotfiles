-- Plain-text "notes" zones. Buffers whose path lives under one of these
-- directories get no markdown features and no spell checking, while markdown
-- everywhere else keeps LazyVim's normal behaviour.
--
-- Edit `M.paths` to add/remove zones. Paths are expanded with `~`.
local M = {}

M.paths = {
  vim.fn.expand("~/notes"),
  vim.fn.expand("~/development/notes"),
  -- vim.fn.expand("~/Documents/Obsidian Vault"),
}

---@param path string|nil
---@return boolean
function M.is_notes(path)
  if not path or path == "" then
    return false
  end
  path = vim.fn.fnamemodify(path, ":p")
  for _, root in ipairs(M.paths) do
    local prefix = vim.fn.fnamemodify(root, ":p"):gsub("/$", "") .. "/"
    if path:sub(1, #prefix) == prefix then
      return true
    end
  end
  return false
end

---@param buf integer
---@return boolean
function M.is_notes_buf(buf)
  return vim.api.nvim_buf_is_valid(buf) and M.is_notes(vim.api.nvim_buf_get_name(buf))
end

--- Make a notes buffer behave as plain text:
---   * no spell checking
---   * no format-on-save
---   * no treesitter markdown highlighting (and re-block Neovim's syntaxset
---     autocmd so it doesn't re-enable Vim's markdown syntax)
---   * no conceal
---   * render-markdown detached, if it is loaded
---@param buf integer
function M.plainify(buf)
  if not M.is_notes_buf(buf) then
    return
  end
  vim.opt_local.spell = false
  vim.b[buf].autoformat = false

  pcall(vim.treesitter.stop, buf)
  vim.b[buf].ts_highlight = true -- block Neovim's `syntaxset` autocmd
  vim.bo[buf].syntax = ""

  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    vim.wo[win].conceallevel = 0
    vim.wo[win].concealcursor = ""
  end

  if package.loaded["render-markdown"] then
    vim.api.nvim_buf_call(buf, function()
      pcall(function()
        require("render-markdown").buf_disable()
      end)
    end)
  end
end

return M
