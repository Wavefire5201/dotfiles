#!/bin/sh
# Waybar wrapper: Codex usage via codexbar (compact bar text + clean tooltip).
#
# Usage: codex-usage.sh [profile] [label]
#
# One ChatGPT workspace = one quota, and codexbar hardcodes both
# $HOME/.codex/auth.json (CREDS) and $HOME/.cache/codexbar (CACHE_DIR) with no
# flag to override either. So a second workspace is tracked by pointing HOME at
# its own profile root; that isolates the credential AND the cache in one go.
#
# With no argument this is the original behaviour: the default ~/.codex login.
#
# NEVER copy auth.json between profiles. OpenAI rotates the refresh token on
# every refresh, so two instances sharing one credential invalidate each other.
# Each profile gets its own login:
#   CODEX_HOME=~/.local/share/codex-profiles/<name>/.codex codex login
# Symlinking auth.json does not work either: codexbar refreshes via
# `jq ... > "$tmp" && mv "$tmp" "$CREDS"`, and that mv replaces the symlink.
profile="$1"
label="$2"

# Resolve the binary before HOME is rewritten, or it points into the profile root.
bin="$HOME/.local/bin/codexbar"

if [ -n "$profile" ]; then
  root="$HOME/.local/share/codex-profiles/$profile"
  # Emit nothing until that workspace is actually logged in — Waybar hides a
  # custom module whose output is empty, so no broken widget in the meantime.
  [ -f "$root/.codex/auth.json" ] || exit 0
  export HOME="$root"
  [ -n "$label" ] || label="Cx $profile"
else
  [ -n "$label" ] || label="Cx"
fi

exec "$bin" \
  --format "$label {session_pct}%" \
  --tooltip-format "Codex${profile:+ ($profile)}
Session  {session_pct}%  ·  {session_reset}
Weekly   {weekly_pct}%  ·  {weekly_reset}"
