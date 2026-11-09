-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.g.clipboard = {
  name = "OSC 52 (copy-only)",
  copy = {
    ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
    ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
  },
  -- paste deliberately omitted: OSC 52 paste queries hang inside zellij.
  -- Use the terminal's native paste (Ctrl+Shift+V) to paste into nvim.
  paste = {
    ["+"] = function() return vim.split(vim.fn.getreg('"'), "\n") end,
    ["*"] = function() return vim.split(vim.fn.getreg('"'), "\n") end,
  },
}
vim.opt.clipboard = "unnamedplus"

-- `nvim some/dir` (incl. bare `chezmoi edit`) should work in that dir, not the
-- shell's cwd; otherwise pickers fall back to cwd and search from ~.
local arg = vim.fn.argv(0)
if vim.fn.argc() == 1 and arg ~= "" and vim.fn.isdirectory(arg) == 1 then
  vim.fn.chdir(arg)
end

-- Machine-local, untracked additions (lua/config/local.lua).
pcall(require, "config.local")
