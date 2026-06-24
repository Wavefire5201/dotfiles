#!/bin/sh
# Waybar wrapper: Codex usage via codexbar (compact bar text + clean tooltip)
exec "$HOME/.local/bin/codexbar" \
  --format 'Cx {session_pct}%' \
  --tooltip-format 'Codex
Session  {session_pct}%  ·  {session_reset}
Weekly   {weekly_pct}%  ·  {weekly_reset}'
