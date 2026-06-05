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
