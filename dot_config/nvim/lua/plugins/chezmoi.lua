return {
  {
    "xvzc/chezmoi.nvim",
    opts = {
      edit = {
        -- LazyVim watches files under ~/.local/share/chezmoi and runs
        -- `chezmoi apply --source-path ...` on save. If the destination has
        -- local edits, chezmoi otherwise prompts for a TTY, which async nvim
        -- jobs do not have.
        force = true,
      },
    },
  },
}
