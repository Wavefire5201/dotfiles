-- ── Prettier / Biome coexistence ────────────────────────────────────────────
-- Both formatting extras are enabled, so each one is gated to only claim the
-- repos it actually owns:
--   * biome    — gated by `require_cwd` in its extra: needs a biome.json
--   * prettier — gated below: needs a Prettier config file
-- conform runs every formatter registered for a filetype in order, so without
-- these gates a repo would get reformatted twice by two disagreeing tools.
--
-- Tradeoff: in a repo with neither config, Prettier no longer runs and
-- formatting falls back to the LSP.
vim.g.lazyvim_prettier_needs_config = true

return {}
