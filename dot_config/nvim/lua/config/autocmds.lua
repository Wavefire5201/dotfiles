-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- ── Notes: plain text (no markdown, no spell check) ──────────────────────────
-- Only paths listed in lua/config/notes.lua are affected; markdown everywhere
-- else keeps LazyVim's normal behaviour (incl. `lazyvim_wrap_spell`).
local notes = require("config.notes")

vim.api.nvim_create_autocmd({ "FileType", "BufReadPost", "BufNewFile", "BufEnter" }, {
  group = vim.api.nvim_create_augroup("notes_plain", { clear = true }),
  callback = function(ev)
    if not notes.is_notes_buf(ev.buf) then
      return
    end
    -- Defer so this runs after every other FileType autocmd (LazyVim's
    -- treesitter start, Neovim's built-in markdown ftplugin, …).
    vim.schedule(function()
      notes.plainify(ev.buf)
    end)
  end,
})

-- Buffers opened from the command line finish their FileType before this file
-- is loaded (VeryLazy), so sweep whatever is already open.
for _, buf in ipairs(vim.api.nvim_list_bufs()) do
  if vim.api.nvim_buf_is_loaded(buf) and notes.is_notes_buf(buf) then
    notes.plainify(buf)
  end
end

-- ── VSCode-style autosave ────────────────────────────────────────────────────
-- Saves ~800ms after you stop typing (debounced), and immediately on focus loss
-- or switching buffers. It saves WITHOUT running format-on-save, so it never
-- reflows code while you edit — a manual :w still formats (LazyVim default).
do
  local group = vim.api.nvim_create_augroup("vscode_autosave", { clear = true })
  local debounce_ms = 800
  local timer

  local function saveable(buf)
    return vim.api.nvim_buf_is_valid(buf)
      and vim.bo[buf].modifiable
      and not vim.bo[buf].readonly
      and vim.bo[buf].buftype == "" -- real files only (skip terminals, prompts, etc.)
      and vim.bo[buf].modified
      and vim.api.nvim_buf_get_name(buf) ~= ""
  end

  local function save(buf)
    if not saveable(buf) then
      return
    end
    local prev = vim.b[buf].autoformat -- suppress LazyVim format-on-save…
    vim.b[buf].autoformat = false -- …for this write only
    vim.api.nvim_buf_call(buf, function()
      vim.cmd("silent! lockmarks update") -- :update = write only if modified
    end)
    vim.b[buf].autoformat = prev
  end

  -- debounced save while editing (resets the timer on every change)
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "InsertLeave" }, {
    group = group,
    desc = "autosave: debounced save after edits",
    callback = function(ev)
      if timer then
        timer:stop()
      end
      timer = vim.defer_fn(function()
        save(ev.buf)
      end, debounce_ms)
    end,
  })

  -- immediate save when you look away (VSCode onFocusChange)
  vim.api.nvim_create_autocmd({ "FocusLost", "BufLeave" }, {
    group = group,
    desc = "autosave: save on focus loss / buffer switch",
    callback = function(ev)
      save(ev.buf)
    end,
  })
end

-- chezmoi templates (*.tmpl) contain {{ }} directives that formatters like
-- stylua can't parse, so don't format them on save.
vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
  pattern = "*.tmpl",
  callback = function() vim.b.autoformat = false end,
})
