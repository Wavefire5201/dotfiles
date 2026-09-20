---
name: noctalia-ai-usage
description: Manage the Noctalia shell's AI usage bar plugin (ai-usage-lite / model-usage) — hide/show providers (claude, codex, antigravity, opencode), change formats, and reload the bar correctly. Use when toggling AI provider widgets, editing Noctalia plugin settings, or restarting/refreshing the noctalia shell.
---

# Noctalia AI Usage Plugin

## Context

Noctalia shell is a Quickshell fork (`qs`, package `noctalia-qs`) running the config at
`/etc/xdg/quickshell/noctalia-shell/shell.qml`, started by hyprland via `exec-once = qs -c noctalia-shell`.
Plugins live in `~/.config/noctalia/plugins/<id>/`. Two AI plugins exist:

- **ai-usage-lite** — the ACTIVE one, registered as a bar widget (`"id": "plugin:ai-usage-lite"` in `~/.config/noctalia/settings.json`). Runs `collector.py` via `uv run --script` on a timer (default 120s, `triggeredOnStart: true`).
- **model-usage** — exists in the plugins dir but is NOT in the bar config; ignore unless added.

Providers: `claude` (Claude Code via `~/.local/bin/claudebar`), `codex`, `antigravity`, `opencode` (OpenCode Go from opencode.ai cookies).

## Settings: source of truth

1. `~/.config/noctalia/plugins/ai-usage-lite/settings.json` — the authoritative per-plugin settings.
   Loaded ONCE at plugin load via `PluginService.loadPluginSettings()` (which literally runs `cat` on it),
   then merged over manifest defaults in `createPluginAPI()`: `pluginSettings = Object.assign({}, defaults, settings)`.
2. `~/.config/noctalia/settings.json` → bar widget `defaultSettings` for `plugin:ai-usage-lite` — a MIRROR used by the bar config UI. Keep it in sync when editing manually.
3. `~/.config/noctalia/plugins/ai-usage-lite/manifest.json` → `metadata.defaultSettings` — fallback only (currently `claudeEnabled: false`).

## GOTCHAS (learned the hard way)

- **External edits to the plugin `settings.json` are NOT picked up live.** The file is only read when the plugin loads. The plugin does NOT watch it.
- There is **no IPC to reload plugins or settings**. `qs -c noctalia-shell ipc call` exposes targets: `bar`, `settings`, `launcher`, `notifications`, `plugin` (openSettings/openPanel only), etc. — no reload/restart. Editing the main `settings.json` only triggers `Settings.settingsReloaded` → `BarService.widgetsRevision++` (bar widget re-sync, NOT plugin re-load).
- The plugin's OWN settings UI works live: its `Settings.qml` calls `pluginApi.saveSettings()`, which writes the file AND replaces the in-memory `pluginSettings` object (binding `cfg: pluginApi.pluginSettings` re-evaluates; picked up on next timer tick).
- So: **manual file edits require a full shell restart** to take effect.

## Procedure: hide a provider (e.g. Claude Code)

1. Edit `~/.config/noctalia/plugins/ai-usage-lite/settings.json`: `"claudeEnabled": false` (or codex/antigravity/opencode).
2. Mirror the change in `~/.config/noctalia/settings.json` (bar `defaultSettings` block for `plugin:ai-usage-lite`) so the config UI doesn't show stale values.
3. Restart the shell:
   ```sh
   qs -c noctalia-shell kill
   qs -c noctalia-shell -d   # relaunch detached
   ```
   (hyprland `exec-once` will NOT restart it — kill is destructive, always relaunch yourself.)
4. Verify the instance is up: `qs list --all` (new PID).

## Verification

The collector runs and exits (short-lived), so reproduce its command manually. With `claudeEnabled: false` the `--claude-enabled` flag must be absent and "claude" gone from output:

```sh
uv run --script ~/.config/noctalia/plugins/ai-usage-lite/collector.py \
  --order "claude,codex,antigravity,opencode" --separator "  " \
  --claude-format "Cl {session_pct}%" --codex-format "Cx {session_pct}%" \
  --antigravity-format "AG {worst_pct}%" --opencode-format "Go {max_pct}%" \
  --codex-enabled --antigravity-enabled --opencode-enabled \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['summary'], [p['id'] for p in d['providers']])"
```

Expected after hiding claude: `Cx 0%  AG ⚠  Go 76%` / `['codex', 'antigravity', 'opencode']`.

## Reference points (noctalia-shell package files)

- `/etc/xdg/quickshell/noctalia-shell/Services/Noctalia/PluginService.qml` — `loadPluginSettings` (~L1256, `cat`-based), `createPluginAPI` (~L974, settings merge), `savePluginSettings` (~L1289, heredoc write).
- `/etc/xdg/quickshell/noctalia-shell/Services/Noctalia/PluginRegistry.qml` — `getPluginSettingsFile` (~L576): `<pluginsDir>/<id>/settings.json`.
- `/etc/xdg/quickshell/noctalia-shell/Services/Control/IPCService.qml` — all IPC targets/functions (check here before assuming a reload IPC exists).
- `/etc/xdg/quickshell/noctalia-shell/Services/UI/BarService.qml` — `onSettingsReloaded` → `widgetsRevision++` (L171-178).
- `/etc/xdg/quickshell/noctalia-shell/Commons/Settings.qml` — external settings file watcher/debounce.

## chezmoi notes

- Plugin RUNTIME settings (`settings.json` files) are NOT chezmoi-managed — only plugin code (`Main.qml`, `Settings.qml`, `collector.py`, `manifest.json`) and `plugins.json` are in `~/.local/share/chezmoi/dot_config/noctalia/`.
- When editing chezmoi-managed noctalia files: edit `~/.local/share/chezmoi/dot_config/noctalia/...` first, then `chezmoi apply`.
