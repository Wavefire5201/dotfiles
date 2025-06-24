return {
  "folke/snacks.nvim",
  opts = {
    scroll = { enabled = false },
    picker = {
      hidden = true,
      sources = {
        files = {
          hidden = true,
          ignored = true,
          exclude = {
            "**/.git/*",
            "**/.venv/*",
          },
        },
      },
    },
  },
}
